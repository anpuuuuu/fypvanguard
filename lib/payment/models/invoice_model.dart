// lib/payment/models/invoice_model.dart
// Invoice data model for payment receipts

import 'package:cloud_firestore/cloud_firestore.dart';

/// Invoice model - stored in Firestore after successful payment
class Invoice {
  final String? id;
  final String userId;
  final String residentId;
  final String transactionId;
  final double amount;
  final String feeType;       // e.g. 'maintenanceFee', 'managementFee'
  final String feeTypeName;   // Display name
  final String? description;
  final DateTime createdAt;
  final String invoiceNumber; // e.g. INV-20250208-001
  final bool emailSent;

  Invoice({
    this.id,
    required this.userId,
    required this.residentId,
    required this.transactionId,
    required this.amount,
    required this.feeType,
    required this.feeTypeName,
    this.description,
    required this.createdAt,
    required this.invoiceNumber,
    this.emailSent = false,
  });

  factory Invoice.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Invoice(
      id: doc.id,
      userId: data['userId'] as String,
      residentId: data['residentId'] as String,
      transactionId: data['transactionId'] as String,
      amount: (data['amount'] as num).toDouble(),
      feeType: data['feeType'] as String,
      feeTypeName: data['feeTypeName'] as String,
      description: data['description'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      invoiceNumber: data['invoiceNumber'] as String,
      emailSent: data['emailSent'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'residentId': residentId,
      'transactionId': transactionId,
      'amount': amount,
      'feeType': feeType,
      'feeTypeName': feeTypeName,
      if (description != null) 'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'invoiceNumber': invoiceNumber,
      'emailSent': emailSent,
    };
  }
}
