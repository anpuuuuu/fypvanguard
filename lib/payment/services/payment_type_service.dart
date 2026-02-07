// lib/payment/services/payment_type_service.dart
// Service for admin-configurable payment types

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_type_model.dart';

class PaymentTypeService {
  static const String _collection = 'settings';
  static const String _docId = 'paymentTypes';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all payment types (creates default if none exist)
  Future<List<PaymentType>> getPaymentTypes() async {
    final doc = await _firestore.collection(_collection).doc(_docId).get();
    if (!doc.exists || doc.data() == null) {
      await _initDefaultPaymentTypes();
      return defaultPaymentTypes;
    }
    final data = doc.data()!;
    final typesList = data['types'] as List<dynamic>? ?? [];
    final types = typesList
        .map((e) => PaymentType.fromMap(e as Map<String, dynamic>))
        .toList();
    types.sort((a, b) => a.order.compareTo(b.order));
    return types;
  }

  /// Initialize with default payment types
  Future<void> _initDefaultPaymentTypes() async {
    await _firestore.collection(_collection).doc(_docId).set({
      'types': defaultPaymentTypes.map((t) => t.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Save payment types (admin only)
  Future<void> savePaymentTypes(List<PaymentType> types) async {
    await _firestore.collection(_collection).doc(_docId).set({
      'types': types.map((t) => t.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Add a payment type
  Future<void> addPaymentType(PaymentType type) async {
    final types = await getPaymentTypes();
    if (types.any((t) => t.key == type.key)) {
      throw Exception('Payment type with key "${type.key}" already exists');
    }
    types.add(type);
    await savePaymentTypes(types);
  }

  /// Update a payment type
  Future<void> updatePaymentType(String oldKey, PaymentType type) async {
    final types = await getPaymentTypes();
    final idx = types.indexWhere((t) => t.key == oldKey);
    if (idx < 0) throw Exception('Payment type not found');
    types[idx] = type;
    await savePaymentTypes(types);
  }

  /// Delete a payment type
  Future<void> deletePaymentType(String key) async {
    final types = await getPaymentTypes();
    types.removeWhere((t) => t.key == key);
    await savePaymentTypes(types);
  }

  /// Get display name for a fee type key (for resident display)
  Future<String> getDisplayName(String key) async {
    final types = await getPaymentTypes();
    final found = types.firstWhere(
      (t) => t.key == key,
      orElse: () => PaymentType(key: key, displayName: _fallbackDisplayName(key)),
    );
    return found.displayName;
  }

  static String _fallbackDisplayName(String key) {
    switch (key) {
      case 'managementFee': return 'Management Fee';
      case 'maintenanceFee': return 'Maintenance Fee';
      case 'maintenance': return 'Maintenance';
      case 'lateFee': return 'Late Fee';
      case 'insurance': return 'Insurance';
      case 'sinking': return 'Sinking Fund';
      case 'waterBill': return 'Water Bill';
      case 'electricBill': return 'Electric Bill';
      default: return key.isEmpty ? 'Other' : key;
    }
  }
}
