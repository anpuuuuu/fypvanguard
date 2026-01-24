import 'package:cloud_firestore/cloud_firestore.dart';

class MaintenanceService {
  final CollectionReference _col = FirebaseFirestore.instance.collection('maintenanceRequests');

  /// Create a new maintenance request with enhanced fields
  Future<String> createRequest({
    required String residentId,
    required String description,
    String? imageBase64,
    String priority = 'medium', // low, medium, high, urgent
    String category = 'general', // general, plumbing, electrical, hvac, structural, other
    String? location, // specific location/unit details
  }) async {
    final docRef = await _col.add({
      'residentId': residentId,
      'description': description,
      'imageBase64': imageBase64,
      'priority': priority,
      'category': category,
      'location': location,
      'status': 'created',
      'assignedTo': null,
      'estimatedCost': null,
      'actualCost': null,
      'estimatedCompletionDate': null,
      'completedAt': null,
      'comments': [],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Add a comment/update to a maintenance request
  Future<void> addComment({
    required String requestId,
    required String userId,
    required String userName,
    required String comment,
  }) async {
    final requestDoc = _col.doc(requestId);
    final requestData = await requestDoc.get();
    final currentComments = (requestData.data() as Map<String, dynamic>?)?['comments'] as List<dynamic>? ?? [];
    
    currentComments.add({
      'userId': userId,
      'userName': userName,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await requestDoc.update({
      'comments': currentComments,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update request status with optional comment
  Future<void> updateRequestStatus({
    required String requestId,
    required String status,
    String? comment,
    String? userId,
    String? userName,
    String? assignedTo,
    double? estimatedCost,
    DateTime? estimatedCompletionDate,
  }) async {
    final updateData = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (assignedTo != null) {
      updateData['assignedTo'] = assignedTo;
    }

    if (estimatedCost != null) {
      updateData['estimatedCost'] = estimatedCost;
    }

    if (estimatedCompletionDate != null) {
      updateData['estimatedCompletionDate'] = Timestamp.fromDate(estimatedCompletionDate);
    }

    if (status == 'resolved') {
      updateData['completedAt'] = FieldValue.serverTimestamp();
    }

    await _col.doc(requestId).update(updateData);

    // Add comment if provided
    if (comment != null && userId != null && userName != null) {
      await addComment(
        requestId: requestId,
        userId: userId,
        userName: userName,
        comment: comment,
      );
    }
  }

  /// Update actual cost when request is completed
  Future<void> updateActualCost(String requestId, double actualCost) async {
    await _col.doc(requestId).update({
      'actualCost': actualCost,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream all pending requests (for security/admin)
  Stream<QuerySnapshot> streamPendingRequests() {
    return FirebaseFirestore.instance
        .collection('maintenanceRequests')
        .where('status', isEqualTo: 'created')
        .snapshots();
  }

  /// Stream all requests (for admin)
  Stream<QuerySnapshot> streamAllRequests() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Stream requests by status
  Stream<QuerySnapshot> streamRequestsByStatus(String status) {
    return _col
        .where('status', isEqualTo: status)
        .snapshots();
  }

  /// Stream requests by priority
  Stream<QuerySnapshot> streamRequestsByPriority(String priority) {
    return _col
        .where('priority', isEqualTo: priority)
        .snapshots();
  }

  /// Stream my requests (for residents)
  Stream<QuerySnapshot> streamMyRequests(String residentId) {
    return _col
        .where('residentId', isEqualTo: residentId)
        .snapshots();
  }

  /// Get request by ID
  Future<DocumentSnapshot> getRequest(String requestId) {
    return _col.doc(requestId).get();
  }

  /// Delete a request (admin only)
  Future<void> deleteRequest(String requestId) {
    return _col.doc(requestId).delete();
  }
}
