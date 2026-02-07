// lib/payment/models/payment_type_model.dart
// Admin-configurable payment types for condominium management

/// Payment type model - defines the types of payments residents can make
class PaymentType {
  final String key;
  final String displayName;
  final String description;
  final int order;

  PaymentType({
    required this.key,
    required this.displayName,
    this.description = '',
    this.order = 0,
  });

  factory PaymentType.fromMap(Map<String, dynamic> data) {
    return PaymentType(
      key: data['key'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      description: data['description'] as String? ?? '',
      order: data['order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'displayName': displayName,
      'description': description,
      'order': order,
    };
  }
}

/// Default payment types for new condominium setups
List<PaymentType> get defaultPaymentTypes => [
  PaymentType(key: 'maintenance', displayName: 'Maintenance', description: 'Monthly maintenance fee', order: 1),
  PaymentType(key: 'managementFee', displayName: 'Management Fee', description: 'Management fee', order: 2),
  PaymentType(key: 'insurance', displayName: 'Insurance', description: 'Building insurance', order: 3),
  PaymentType(key: 'sinking', displayName: 'Sinking Fund', description: 'Sinking fund contribution', order: 4),
  PaymentType(key: 'waterBill', displayName: 'Water Bill', description: 'Water utility charges', order: 5),
  PaymentType(key: 'electricBill', displayName: 'Electric Bill', description: 'Electricity charges', order: 6),
  PaymentType(key: 'lateFee', displayName: 'Late Fee', description: 'Late payment penalty', order: 7),
  PaymentType(key: 'other', displayName: 'Other', description: 'Other fees', order: 8),
];
