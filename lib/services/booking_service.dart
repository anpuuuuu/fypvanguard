import 'package:cloud_firestore/cloud_firestore.dart';

class BookingService {
  final CollectionReference _col = FirebaseFirestore.instance.collection('bookings');

  Future<void> createBooking({
    required String residentId,
    required String facilityId,
    required DateTime bookingDate,
    required int durationHours,
  }) {
    return _col.add({
      'residentId': residentId,
      'facilityId': facilityId,
      'bookingDate': Timestamp.fromDate(bookingDate),
      'durationHours': durationHours,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> streamMyBookings(String residentId) {
    return _col
        .where('residentId', isEqualTo: residentId)
        .orderBy('bookingDate', descending: false)
        .snapshots();
  }

  Stream<QuerySnapshot> streamPendingBookings() {
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('status', isEqualTo: 'pending')
        .orderBy('bookingDate')
        .snapshots();
  }

  Future<void> cancelBooking(String bookingId) {
    return _col.doc(bookingId).update({'status': 'cancelled'});
  }

  Future<void> updateBookingStatus(String bookingId, String status) {
    return _col.doc(bookingId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}