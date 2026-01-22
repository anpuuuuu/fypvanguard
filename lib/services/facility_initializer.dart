// lib/services/facility_initializer.dart
// 设施初始化工具 - 用于添加默认设施

import 'package:cloud_firestore/cloud_firestore.dart';

class FacilityInitializer {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 默认设施配置
  static final List<Map<String, dynamic>> defaultFacilities = [
    {
      'name': 'Swimming Pool',
      'startHour': 6,
      'endHour': 22,
      'maxSlots': 10,
      'active': true,
    },
    {
      'name': 'Basketball Court',
      'startHour': 7,
      'endHour': 22,
      'maxSlots': 10,
      'active': true,
    },
  ];

  /// 检查并初始化设施
  /// 只添加不存在的设施
  Future<List<String>> initializeDefaultFacilities() async {
    final collection = _firestore.collection('facilities');
    final addedFacilities = <String>[];

    for (final facility in defaultFacilities) {
      final name = facility['name'] as String;
      
      // 检查是否已存在
      final existing = await collection
          .where('name', isEqualTo: name)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        // 不存在，添加新设施
        await collection.add({
          ...facility,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        addedFacilities.add(name);
      }
    }

    return addedFacilities;
  }

  /// 强制添加/更新设施（会覆盖现有数据）
  Future<void> forceInitializeFacilities() async {
    final collection = _firestore.collection('facilities');

    for (final facility in defaultFacilities) {
      final name = facility['name'] as String;
      
      // 查找是否已存在
      final existing = await collection
          .where('name', isEqualTo: name)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        // 存在，更新
        await collection.doc(existing.docs.first.id).update({
          ...facility,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // 不存在，添加
        await collection.add({
          ...facility,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  /// 更新现有设施的 maxSlots（如果之前没有设置）
  Future<int> updateExistingFacilitiesMaxSlots({int defaultMaxSlots = 10}) async {
    final collection = _firestore.collection('facilities');
    final snap = await collection.get();
    
    int updated = 0;
    
    for (final doc in snap.docs) {
      final data = doc.data();
      // 如果 maxSlots 不存在或为 null，设置默认值
      if (data['maxSlots'] == null) {
        await collection.doc(doc.id).update({
          'maxSlots': defaultMaxSlots,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        updated++;
      }
    }
    
    return updated;
  }
}
