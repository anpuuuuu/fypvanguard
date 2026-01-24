// lib/payment/controllers/payment_controller.dart
// Payment controller - Handles payment business logic

import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/transaction_model.dart';
import '../services/blockchain_service.dart';
import '../services/payment_gateway_service.dart';

/// Payment controller
class PaymentController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final BlockchainService _blockchainService = BlockchainService();
  final PaymentGatewayService _paymentGatewayService = PaymentGatewayService();

  /// Initialize services
  Future<void> initialize() async {
    await _blockchainService.initialize();
    await _paymentGatewayService.initialize();
  }

  /// Process blockchain payment
  /// [amount] - Payment amount (ETH)
  /// [feeType] - Fee type
  /// [fromAddress] - Sender address (from Ganache)
  /// [privateKey] - User private key (should be retrieved from secure storage)
  /// [toAddress] - Recipient address (management address)
  /// [description] - Payment description
  Future<Transaction> processBlockchainPayment({
    required double amount,
    required FeeType feeType,
    required String fromAddress,
    required String privateKey,
    required String toAddress,
    String? description,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Get user information
    final accountDoc = await _firestore
        .collection('accounts')
        .doc(user.uid)
        .get();
    final accountData = accountDoc.data();
    final residentId = accountData?['residentId'] as String? ?? user.uid;

    // Create pending transaction record
    final transaction = Transaction(
      userId: user.uid,
      residentId: residentId,
      amount: amount,
      feeType: feeType,
      paymentMethod: PaymentMethod.blockchain,
      status: TransactionStatus.pending,
      createdAt: DateTime.now(),
      toAddress: toAddress,
      description: description,
    );

    // Save to Firestore
    final docRef = await _firestore
        .collection('transactions')
        .add(transaction.toFirestore());

    try {
      // Update status to processing
      await docRef.update({
        'status': TransactionStatus.processing.toString().split('.').last,
      });

      // Send blockchain transaction
      final transactionHash = await _blockchainService.sendTransaction(
        fromAddress: fromAddress,
        privateKey: privateKey,
        toAddress: toAddress,
        amount: amount,
      );

      // Wait for transaction confirmation (optional, can be processed asynchronously)
      Map<String, dynamic>? receipt;
      try {
        receipt = await _blockchainService.waitForConfirmation(
          transactionHash,
          maxWaitTime: 30,
        );
      } catch (e) {
        // If timeout, transaction may still be pending, but we can record the hash
        // In actual applications, can use background tasks to check transaction status
      }

      // Update transaction record
      final updateData = <String, dynamic>{
        'status': TransactionStatus.completed.toString().split('.').last,
        'transactionHash': transactionHash,
        'fromAddress': fromAddress,
        'completedAt': FieldValue.serverTimestamp(),
      };

      if (receipt != null && receipt['blockNumber'] != null) {
        updateData['blockNumber'] = receipt['blockNumber'];
      }

      await docRef.update(updateData);

      // Mark pending fees as paid (if any)
      final updatedDoc = await docRef.get();
      final transaction = Transaction.fromFirestore(updatedDoc);
      await _markPendingFeesAsPaid(residentId, feeType, amount, transaction.id);

      // Return updated transaction
      return transaction;
    } catch (e) {
      // Update to failed status
      await docRef.update({
        'status': TransactionStatus.failed.toString().split('.').last,
      });
      throw Exception('Blockchain payment failed: $e');
    }
  }

  /// Process traditional payment (Stripe)
  /// [amount] - Payment amount
  /// [feeType] - Fee type
  /// [paymentMethodId] - Stripe payment method ID
  /// [description] - Payment description
  Future<Transaction> processStripePayment({
    required double amount,
    required FeeType feeType,
    required String paymentMethodId,
    String? description,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Get user information
    final accountDoc = await _firestore
        .collection('accounts')
        .doc(user.uid)
        .get();
    final accountData = accountDoc.data();
    final residentId = accountData?['residentId'] as String? ?? user.uid;

    // Create payment intent
    final paymentIntent = await _paymentGatewayService.createPaymentIntent(
      amount: amount,
      currency: 'MYR', // Malaysian Ringgit, can be modified as needed
      metadata: {
        'userId': user.uid,
        'residentId': residentId,
        'feeType': feeType.toString().split('.').last,
      },
    );

    final paymentIntentId = paymentIntent['id'] as String;

    // Create pending transaction record
    final transaction = Transaction(
      userId: user.uid,
      residentId: residentId,
      amount: amount,
      feeType: feeType,
      paymentMethod: PaymentMethod.stripe,
      status: TransactionStatus.pending,
      createdAt: DateTime.now(),
      paymentIntentId: paymentIntentId,
      description: description,
    );

    // Save to Firestore
    final docRef = await _firestore
        .collection('transactions')
        .add(transaction.toFirestore());

    try {
      // Update status to processing
      await docRef.update({
        'status': TransactionStatus.processing.toString().split('.').last,
      });

      // Confirm payment
      await _paymentGatewayService.confirmPayment(
        paymentIntentId: paymentIntentId,
        paymentMethodId: paymentMethodId,
      );

      // Get payment status
      final paymentStatus = await _paymentGatewayService.getPaymentStatus(
        paymentIntentId,
      );

      final status = paymentStatus['status'] as String;
      final isSucceeded = status == 'succeeded';

      // Update transaction record
      await docRef.update({
        'status': isSucceeded
            ? TransactionStatus.completed.toString().split('.').last
            : TransactionStatus.failed.toString().split('.').last,
        'receiptId': paymentStatus['charges']?['data']?[0]?['receipt_url'] as String?,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Mark pending fees as paid (if any)
      final updatedDoc = await docRef.get();
      final transaction = Transaction.fromFirestore(updatedDoc);
      await _markPendingFeesAsPaid(residentId, feeType, amount, transaction.id);

      // Return updated transaction
      return transaction;
    } catch (e) {
      // Update to failed status
      await docRef.update({
        'status': TransactionStatus.failed.toString().split('.').last,
      });
      throw Exception('Stripe payment failed: $e');
    }
  }

  /// Mark pending fees as paid when payment is completed
  Future<void> _markPendingFeesAsPaid(
    String residentId,
    FeeType feeType,
    double amount,
    String? transactionId,
  ) async {
    try {
      // Find matching pending fees
      final pendingFeesSnapshot = await _firestore
          .collection('pendingFees')
          .where('residentId', isEqualTo: residentId)
          .where('status', isEqualTo: 'pending')
          .where('feeType', isEqualTo: feeType.toString().split('.').last)
          .get();

      // Mark fees as paid (match by amount or mark all matching type)
      for (var doc in pendingFeesSnapshot.docs) {
        final feeAmount = (doc.data()['amount'] as num).toDouble();
        // Mark as paid if amount matches (or within small tolerance)
        if ((feeAmount - amount).abs() < 0.01) {
          await doc.reference.update({
            'status': 'paid',
            'paidAt': FieldValue.serverTimestamp(),
            if (transactionId != null) 'transactionId': transactionId,
          });
        }
      }
    } catch (e) {
      // Don't throw error, just log it
      print('Error marking pending fees as paid: $e');
    }
  }

  /// Get user's transaction history
  /// Note: Using separate queries to avoid Firestore index requirement
  Stream<List<Transaction>> getTransactionHistory(String userId) {
    return _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final transactions = snapshot.docs
              .map((doc) => Transaction.fromFirestore(doc))
              .toList();
          // Sort in memory to avoid Firestore index requirement
          transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return transactions;
        });
  }

  /// Get all transactions (for admin)
  Stream<List<Transaction>> getAllTransactions() {
    return _firestore
        .collection('transactions')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Transaction.fromFirestore(doc))
            .toList());
  }

  /// Get transactions by status (for admin)
  Stream<List<Transaction>> getTransactionsByStatus(TransactionStatus status) {
    final statusStr = status.toString().split('.').last;
    return _firestore
        .collection('transactions')
        .where('status', isEqualTo: statusStr)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Transaction.fromFirestore(doc))
            .toList());
  }

  /// Get specific transaction
  Future<Transaction?> getTransaction(String transactionId) async {
    final doc = await _firestore
        .collection('transactions')
        .doc(transactionId)
        .get();
    
    if (!doc.exists) return null;
    return Transaction.fromFirestore(doc);
  }

  /// Get pending fees list
  /// Can query fees that need to be paid based on business logic
  /// For example: management fees, late fees, etc.
  Future<List<Map<String, dynamic>>> getPendingFees(String residentId) async {
    final fees = <Map<String, dynamic>>[];

    // Query pending fees from Firestore (pushed by admin)
    try {
      final pendingFeesSnapshot = await _firestore
          .collection('pendingFees')
          .where('residentId', isEqualTo: residentId)
          .where('status', isEqualTo: 'pending')
          .get();

      for (var doc in pendingFeesSnapshot.docs) {
        final data = doc.data();
        final feeTypeStr = data['feeType'] as String? ?? 'other';
        final feeType = FeeType.values.firstWhere(
          (e) => e.toString().split('.').last == feeTypeStr,
          orElse: () => FeeType.other,
        );

        fees.add({
          'id': doc.id,
          'type': feeType,
          'amount': (data['amount'] as num).toDouble(),
          'description': data['description'] as String? ?? '',
          'dueDate': data['dueDate'] != null
              ? (data['dueDate'] as Timestamp).toDate()
              : null,
        });
      }
    } catch (e) {
      print('Error loading pending fees: $e');
    }

    // Check if there are unpaid management fees (from resident profile)
    final managementFee = await _getManagementFee(residentId);
    if (managementFee != null && managementFee['amount'] > 0) {
      fees.add({
        'type': FeeType.managementFee,
        'amount': managementFee['amount'],
        'description': 'Management Fee - ${managementFee['period']}',
        'dueDate': managementFee['dueDate'],
      });
    }

    // Check if there are late fees
    final lateFees = await _getLateFees(residentId);
    fees.addAll(lateFees);

    return fees;
  }

  /// Get management fee (example implementation)
  Future<Map<String, dynamic>?> _getManagementFee(String residentId) async {
    // Should query actual management fee configuration from Firestore
    // Example implementation
    try {
      final residentDoc = await _firestore
          .collection('residents')
          .doc(residentId)
          .get();
      
      final data = residentDoc.data();
      final monthlyFee = data?['monthlyManagementFee'] as double? ?? 0.0;
      
      if (monthlyFee > 0) {
        return {
          'amount': monthlyFee,
          'period': '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}',
          'dueDate': DateTime.now().add(const Duration(days: 7)),
        };
      }
    } catch (e) {
      // Handle error
    }
    return null;
  }

  /// Get late fees (example implementation)
  Future<List<Map<String, dynamic>>> _getLateFees(String residentId) async {
    // Should query actual unpaid fees and calculate late fees
    // Example implementation
    return [];
  }

  /// Dispose resources
  void dispose() {
    _blockchainService.dispose();
  }
}
