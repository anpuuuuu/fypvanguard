// lib/payment/controllers/payment_controller.dart
// Payment controller - Handles payment business logic

import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/transaction_model.dart';
import '../models/invoice_model.dart';
import '../services/blockchain_service.dart';
import '../services/payment_gateway_service.dart';
import '../services/payment_type_service.dart';
import '../services/wallet_service.dart';

/// Payment controller
class PaymentController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final BlockchainService _blockchainService = BlockchainService();
  final PaymentGatewayService _paymentGatewayService = PaymentGatewayService();

  /// Initialize services (BlockchainService loads rpcUrl; WalletService loads managementWalletAddress from Firestore for cross-PC testing).
  Future<void> initialize() async {
    await _blockchainService.initialize();
    await WalletService.initialize();
    await _paymentGatewayService.initialize();
  }

  /// Process blockchain payment
  /// [amount] - Payment amount in RM (Malaysian Ringgit)
  /// [ethAmount] - Payment amount in ETH (converted from RM)
  /// [feeType] - Fee type (for transaction record)
  /// [feeTypeKey] - Fee type key string for matching pending fees (e.g. 'maintenance', 'insurance')
  /// [fromAddress] - Sender address (from Ganache)
  /// [privateKey] - User private key (should be retrieved from secure storage)
  /// [toAddress] - Recipient address (management address)
  /// [description] - Payment description
  Future<Transaction> processBlockchainPayment({
    required double amount, // RM amount (original)
    required double ethAmount, // ETH amount (converted)
    required FeeType feeType,
    String? feeTypeKey,
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
    // Store original RM amount, not ETH amount
    final transaction = Transaction(
      userId: user.uid,
      residentId: residentId,
      amount: amount, // Store original RM amount
      feeType: feeType,
      paymentMethod: PaymentMethod.blockchain,
      status: TransactionStatus.pending,
      createdAt: DateTime.now(),
      toAddress: toAddress,
      description: description,
      metadata: {
        'ethAmount': ethAmount, // Store ETH amount in metadata
        'conversionRate': ethAmount / amount, // Store conversion rate
      },
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

      // Send blockchain transaction using ETH amount
      final transactionHash = await _blockchainService.sendTransaction(
        fromAddress: fromAddress,
        privateKey: privateKey,
        toAddress: toAddress,
        amount: ethAmount, // Use converted ETH amount
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
      final feeTypeStr = feeTypeKey ?? feeType.toString().split('.').last;
      await _markPendingFeesAsPaid(residentId, feeTypeStr, amount, transaction.id);

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

  /// Process PayPal Sandbox payment (card) - no real charge, valid card only
  /// [amount] - Payment amount
  /// [feeType] - Fee type (for transaction record)
  /// [feeTypeKey] - Fee type key string for matching pending fees
  /// [feeTypeName] - Display name for invoice
  /// [paymentMethodId] - Payment method ID (from card form)
  /// [description] - Payment description
  Future<Transaction> processPayPalPayment({
    required double amount,
    required FeeType feeType,
    String? feeTypeKey,
    required String feeTypeName,
    required String paymentMethodId,
    String? description,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final accountDoc = await _firestore
        .collection('accounts')
        .doc(user.uid)
        .get();
    final accountData = accountDoc.data();
    final residentId = accountData?['residentId'] as String? ?? user.uid;
    final feeTypeStr = feeTypeKey ?? feeType.toString().split('.').last;

    // Create order (PayPal Sandbox simulated)
    final order = await _paymentGatewayService.createOrder(
      amount: amount,
      currency: 'MYR',
      metadata: {
        'userId': user.uid,
        'residentId': residentId,
        'feeType': feeTypeStr,
      },
    );
    final orderId = order['id'] as String;

    // Create pending transaction
    final transaction = Transaction(
      userId: user.uid,
      residentId: residentId,
      amount: amount,
      feeType: feeType,
      paymentMethod: PaymentMethod.paypal,
      status: TransactionStatus.pending,
      createdAt: DateTime.now(),
      paymentIntentId: orderId,
      description: description,
    );

    final docRef = await _firestore
        .collection('transactions')
        .add(transaction.toFirestore());

    try {
      await docRef.update({
        'status': TransactionStatus.processing.toString().split('.').last,
      });

      await _paymentGatewayService.captureOrder(
        orderId: orderId,
        paymentMethodId: paymentMethodId,
      );

      final paymentStatus = await _paymentGatewayService.getPaymentStatus(orderId);
      final status = paymentStatus['status'] as String;
      final isSucceeded = status == 'COMPLETED';
      final receiptUrl = paymentStatus['receipt_url'] as String?;

      if (!isSucceeded) {
        await docRef.update({
          'status': TransactionStatus.failed.toString().split('.').last,
        });
        throw Exception('PayPal sandbox payment did not complete');
      }

      // Create invoice and get invoice number
      final invoice = await _createInvoice(
        userId: user.uid,
        residentId: residentId,
        transactionId: docRef.id,
        amount: amount,
        feeType: feeTypeStr,
        feeTypeName: feeTypeName,
        description: description,
      );

      await docRef.update({
        'status': TransactionStatus.completed.toString().split('.').last,
        'receiptId': receiptUrl,
        'completedAt': FieldValue.serverTimestamp(),
        'invoiceId': invoice.id,
      });

      await _markPendingFeesAsPaid(residentId, feeTypeStr, amount, docRef.id);

      final updatedDoc = await docRef.get();
      return Transaction.fromFirestore(updatedDoc);
    } catch (e) {
      await docRef.update({
        'status': TransactionStatus.failed.toString().split('.').last,
      });
      throw Exception('PayPal payment failed: $e');
    }
  }

  /// Create invoice after successful payment; stored in Firestore for email trigger
  Future<Invoice> _createInvoice({
    required String userId,
    required String residentId,
    required String transactionId,
    required double amount,
    required String feeType,
    required String feeTypeName,
    String? description,
  }) async {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final unique = now.millisecondsSinceEpoch % 10000;
    final invoiceNumber = 'INV-$dateStr-${unique.toString().padLeft(4, '0')}';

    final invoice = Invoice(
      userId: userId,
      residentId: residentId,
      transactionId: transactionId,
      amount: amount,
      feeType: feeType,
      feeTypeName: feeTypeName,
      description: description,
      createdAt: now,
      invoiceNumber: invoiceNumber,
      emailSent: false,
    );

    final invoiceRef = await _firestore
        .collection('invoices')
        .add(invoice.toFirestore());

    return Invoice(
      id: invoiceRef.id,
      userId: invoice.userId,
      residentId: invoice.residentId,
      transactionId: invoice.transactionId,
      amount: invoice.amount,
      feeType: invoice.feeType,
      feeTypeName: invoice.feeTypeName,
      description: invoice.description,
      createdAt: invoice.createdAt,
      invoiceNumber: invoice.invoiceNumber,
      emailSent: invoice.emailSent,
    );
  }

  /// Get invoices for user (past invoices). Sorted in memory to avoid composite index.
  Stream<List<Invoice>> getInvoices(String userId) {
    return _firestore
        .collection('invoices')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => Invoice.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Get recent invoices (e.g. last 5) for payment page. Sorted in memory to avoid composite index.
  Future<List<Invoice>> getRecentInvoices(String userId, {int limit = 5}) async {
    final snapshot = await _firestore
        .collection('invoices')
        .where('userId', isEqualTo: userId)
        .get();
    final list = snapshot.docs
        .map((doc) => Invoice.fromFirestore(doc))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.take(limit).toList();
  }

  /// Get single invoice by id
  Future<Invoice?> getInvoice(String invoiceId) async {
    final doc = await _firestore.collection('invoices').doc(invoiceId).get();
    if (!doc.exists) return null;
    return Invoice.fromFirestore(doc);
  }

  /// Complete payment after PayPal sandbox order capture (user approved in PayPal).
  /// Creates transaction + invoice and marks pending fees paid.
  /// [feeTypeKey] - e.g. 'maintenanceFee', 'managementFee'
  Future<Transaction> completePayPalPaymentFromCapture({
    required String userId,
    required String residentId,
    required double amount,
    required String feeTypeKey,
    required String feeTypeName,
    required String orderId,
    String? description,
  }) async {
    final feeType = FeeType.values.firstWhere(
      (e) => e.toString().split('.').last == feeTypeKey,
      orElse: () => FeeType.other,
    );
    final transaction = Transaction(
      userId: userId,
      residentId: residentId,
      amount: amount,
      feeType: feeType,
      paymentMethod: PaymentMethod.paypal,
      status: TransactionStatus.completed,
      createdAt: DateTime.now(),
      completedAt: DateTime.now(),
      paymentIntentId: orderId,
      receiptId: 'https://www.sandbox.paypal.com/checkoutnow?token=$orderId',
      description: description,
    );

    final docRef = await _firestore
        .collection('transactions')
        .add(transaction.toFirestore());

    final invoice = await _createInvoice(
      userId: userId,
      residentId: residentId,
      transactionId: docRef.id,
      amount: amount,
      feeType: feeTypeKey,
      feeTypeName: feeTypeName,
      description: description,
    );

    await docRef.update({
      'invoiceId': invoice.id,
    });

    await _markPendingFeesAsPaid(residentId, feeTypeKey, amount, docRef.id);

    final updatedDoc = await docRef.get();
    return Transaction.fromFirestore(updatedDoc);
  }

  /// Mark pending fees as paid when payment is completed
  /// [feeTypeStr] - Fee type key string (e.g. 'maintenance', 'insurance', 'maintenanceFee')
  Future<void> _markPendingFeesAsPaid(
    String residentId,
    String feeTypeStr,
    double amount,
    String? transactionId,
  ) async {
    try {
      // Find matching pending fees
      final pendingFeesSnapshot = await _firestore
          .collection('pendingFees')
          .where('residentId', isEqualTo: residentId)
          .where('status', isEqualTo: 'pending')
          .where('feeType', isEqualTo: feeTypeStr)
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
  /// Returns fees with typeKey (for payment processing) and typeName (for display from admin config)
  Future<List<Map<String, dynamic>>> getPendingFees(String residentId) async {
    final fees = <Map<String, dynamic>>[];
    final paymentTypeService = PaymentTypeService();

    // Query pending fees from Firestore (pushed by admin)
    try {
      final pendingFeesSnapshot = await _firestore
          .collection('pendingFees')
          .where('residentId', isEqualTo: residentId)
          .where('status', isEqualTo: 'pending')
          .get();

      for (var doc in pendingFeesSnapshot.docs) {
        final data = doc.data();
        final feeTypeKey = data['feeType'] as String? ?? 'other';
        final feeType = FeeType.values.firstWhere(
          (e) => e.toString().split('.').last == feeTypeKey,
          orElse: () => FeeType.other,
        );
        final typeName = await paymentTypeService.getDisplayName(feeTypeKey);

        fees.add({
          'id': doc.id,
          'type': feeType,
          'typeKey': feeTypeKey,
          'typeName': typeName,
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
        'typeKey': 'managementFee',
        'typeName': await paymentTypeService.getDisplayName('managementFee'),
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
