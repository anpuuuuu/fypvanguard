// lib/payment/models/transaction_model.dart
// Transaction data model

import 'package:cloud_firestore/cloud_firestore.dart';

/// Payment method enumeration
enum PaymentMethod {
  blockchain,   // Blockchain payment
  stripe,       // Stripe payment
  paypal,       // PayPal card (form)
  paypalAccount, // PayPal sandbox account (login on PayPal)
}

/// Transaction status enumeration
enum TransactionStatus {
  pending,   // Pending
  processing, // Processing
  completed, // Completed
  failed,    // Failed
  cancelled, // Cancelled
}

/// Fee type enumeration
enum FeeType {
  managementFee,  // Management fee
  maintenanceFee, // Maintenance fee
  lateFee,        // Late fee
  other,          // Other
}

/// Transaction model
class Transaction {
  final String? id;
  final String userId;
  final String residentId;
  final double amount;
  final FeeType feeType;
  final PaymentMethod paymentMethod;
  final TransactionStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  
  // Blockchain related fields
  final String? transactionHash; // Blockchain transaction hash
  final String? fromAddress;      // Sender address
  final String? toAddress;         // Recipient address
  final int? blockNumber;         // Block number
  
  // Traditional payment related fields
  final String? receiptId;        // Receipt URL (Stripe/PayPal)
  final String? paymentIntentId; // Payment intent / order ID
  final String? invoiceId;       // Invoice document ID (for PayPal/card payments)
  
  // Metadata
  final String? description;
  final Map<String, dynamic>? metadata;

  Transaction({
    this.id,
    required this.userId,
    required this.residentId,
    required this.amount,
    required this.feeType,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.transactionHash,
    this.fromAddress,
    this.toAddress,
    this.blockNumber,
    this.receiptId,
    this.paymentIntentId,
    this.invoiceId,
    this.description,
    this.metadata,
  });

  /// Create Transaction object from Firestore document
  factory Transaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Transaction(
      id: doc.id,
      userId: data['userId'] as String,
      residentId: data['residentId'] as String,
      amount: (data['amount'] as num).toDouble(),
      feeType: FeeType.values.firstWhere(
        (e) => e.toString().split('.').last == data['feeType'],
        orElse: () => FeeType.other,
      ),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.toString().split('.').last == data['paymentMethod'],
        orElse: () => PaymentMethod.stripe,
      ),
      status: TransactionStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => TransactionStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      transactionHash: data['transactionHash'] as String?,
      fromAddress: data['fromAddress'] as String?,
      toAddress: data['toAddress'] as String?,
      blockNumber: data['blockNumber'] as int?,
      receiptId: data['receiptId'] as String?,
      paymentIntentId: data['paymentIntentId'] as String?,
      invoiceId: data['invoiceId'] as String?,
      description: data['description'] as String?,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to Firestore document data
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'residentId': residentId,
      'amount': amount,
      'feeType': feeType.toString().split('.').last,
      'paymentMethod': paymentMethod.toString().split('.').last,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      if (transactionHash != null) 'transactionHash': transactionHash,
      if (fromAddress != null) 'fromAddress': fromAddress,
      if (toAddress != null) 'toAddress': toAddress,
      if (blockNumber != null) 'blockNumber': blockNumber,
      if (receiptId != null) 'receiptId': receiptId,
      if (paymentIntentId != null) 'paymentIntentId': paymentIntentId,
      if (invoiceId != null) 'invoiceId': invoiceId,
      if (description != null) 'description': description,
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Get fee type display name
  String get feeTypeDisplayName {
    switch (feeType) {
      case FeeType.managementFee:
        return 'Management Fee';
      case FeeType.maintenanceFee:
        return 'Maintenance Fee';
      case FeeType.lateFee:
        return 'Late Fee';
      case FeeType.other:
        return 'Other Fee';
    }
  }

  /// Get payment method display name
  String get paymentMethodDisplayName {
    switch (paymentMethod) {
      case PaymentMethod.blockchain:
        return 'Blockchain Payment';
      case PaymentMethod.stripe:
        return 'Credit/Debit Card';
      case PaymentMethod.paypal:
        return 'PayPal (Sandbox)';
      case PaymentMethod.paypalAccount:
        return 'PayPal Account';
    }
  }

  /// Get status display name
  String get statusDisplayName {
    switch (status) {
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.processing:
        return 'Processing';
      case TransactionStatus.completed:
        return 'Completed';
      case TransactionStatus.failed:
        return 'Failed';
      case TransactionStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Copy and update fields
  Transaction copyWith({
    String? id,
    String? userId,
    String? residentId,
    double? amount,
    FeeType? feeType,
    PaymentMethod? paymentMethod,
    TransactionStatus? status,
    DateTime? createdAt,
    DateTime? completedAt,
    String? transactionHash,
    String? fromAddress,
    String? toAddress,
    int? blockNumber,
    String? receiptId,
    String? paymentIntentId,
    String? invoiceId,
    String? description,
    Map<String, dynamic>? metadata,
  }) {
    return Transaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      residentId: residentId ?? this.residentId,
      amount: amount ?? this.amount,
      feeType: feeType ?? this.feeType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      transactionHash: transactionHash ?? this.transactionHash,
      fromAddress: fromAddress ?? this.fromAddress,
      toAddress: toAddress ?? this.toAddress,
      blockNumber: blockNumber ?? this.blockNumber,
      receiptId: receiptId ?? this.receiptId,
      paymentIntentId: paymentIntentId ?? this.paymentIntentId,
      invoiceId: invoiceId ?? this.invoiceId,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
    );
  }
}
