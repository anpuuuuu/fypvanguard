import 'package:cloud_firestore/cloud_firestore.dart';

class MaintenanceService {
  final CollectionReference _col = FirebaseFirestore.instance.collection('maintenanceRequests');

  Future<void> createRequest({
    required String residentId,
    required String description,
    String? imageBase64,
  }) {
    return _col.add({
      'residentId': residentId,
      'description': description,
      'imageBase64': imageBase64,
      'status': 'created',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }


  Stream<QuerySnapshot> streamPendingRequests() {
    return FirebaseFirestore.instance
        .collection('maintenanceRequests')
        .where('status', isEqualTo: 'created')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> streamMyRequests(String residentId) {
    return _col
        .where('residentId', isEqualTo: residentId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> updateRequestStatus(String requestId, String status) {
    return _col.doc(requestId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
