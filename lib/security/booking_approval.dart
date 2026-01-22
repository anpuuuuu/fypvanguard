// lib/security/booking_approval.dart
// 设施预订记录页面 - Security 查看预订记录（只读）

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class BookingApprovalPage extends StatefulWidget {
  const BookingApprovalPage({Key? key}) : super(key: key);

  @override
  _BookingApprovalPageState createState() => _BookingApprovalPageState();
}

class _BookingApprovalPageState extends State<BookingApprovalPage> {
  final int _currentIndex = 3;
  String _searchQuery = '';
  String _filterDate = 'Today'; // 'Today', 'This Week', 'All'

  /// Fetch resident's info
  Future<Map<String, String>> _fetchResidentInfo(String residentId) async {
    final doc = await FirebaseFirestore.instance
        .collection('residents')
        .doc(residentId)
        .get();
    final data = doc.data() ?? {};
    return {
      'fullName': data['fullName'] as String? ?? 'Unknown',
      'unit': data['unitNumber'] as String? ?? 'Unknown',
      'phone': data['contactNumber'] as String? ?? '-',
    };
  }

  /// Fetch facility name
  Future<String> _fetchFacilityName(String facilityId) async {
    final doc = await FirebaseFirestore.instance
        .collection('facilities')
        .doc(facilityId)
        .get();
    return doc.data()?['name'] as String? ?? facilityId;
  }

  /// Get date filter bounds
  DateTime? _getFilterStartDate() {
    final now = DateTime.now();
    switch (_filterDate) {
      case 'Today':
        return DateTime(now.year, now.month, now.day);
      case 'This Week':
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(monday.year, monday.month, monday.day);
      case 'All':
      default:
        return null;
    }
  }

  /// Handle bottom nav taps
  void _onNavTap(int index) {
    switch (index) {
      case 0:
        GoRouter.of(context).go('/security');
        break;
      case 1:
        GoRouter.of(context).go('/security/visitorApproval');
        break;
      case 2:
        GoRouter.of(context).go('/security/visitorTracking');
        break;
      case 3:
        // already here
        break;
      case 4:
        GoRouter.of(context).go('/security/maintenanceReview');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build query based on filter
    final filterStart = _getFilterStartDate();
    Query query = FirebaseFirestore.instance
        .collection('bookings')
        .where('status', isEqualTo: 'approved');

    if (filterStart != null) {
      query = query.where('bookingDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(filterStart));
    }

    query = query.orderBy('bookingDate', descending: false);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        title: Text('Facility Bookings',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/security'),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or facility',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            ),
          ),

          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('Filter: ', style: GoogleFonts.montserrat(fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                _buildFilterChip('Today'),
                const SizedBox(width: 8),
                _buildFilterChip('This Week'),
                const SizedBox(width: 8),
                _buildFilterChip('All'),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Booking list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (ctx, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text('Error: ${snap.error}',
                        style: GoogleFonts.montserrat(color: Colors.red)),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_available, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('No bookings found',
                            style: GoogleFonts.montserrat(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data()! as Map<String, dynamic>;

                    return FutureBuilder<List<Object>>(
                      future: Future.wait([
                        _fetchResidentInfo(data['residentId'] as String),
                        _fetchFacilityName(data['facilityId'] as String),
                      ]),
                      builder: (ctx2, fb) {
                        if (!fb.hasData) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: const CircularProgressIndicator(strokeWidth: 2),
                              title: Text('Loading...', style: GoogleFonts.montserrat()),
                            ),
                          );
                        }

                        final residentInfo = fb.data![0] as Map<String, String>;
                        final facilityName = fb.data![1] as String;

                        // Apply search filter
                        if (_searchQuery.isNotEmpty) {
                          final searchText =
                              '${residentInfo['fullName']} ${residentInfo['unit']} $facilityName'
                                  .toLowerCase();
                          if (!searchText.contains(_searchQuery)) {
                            return const SizedBox.shrink();
                          }
                        }

                        final ts = (data['bookingDate'] as Timestamp).toDate().toLocal();
                        final end = ts.add(Duration(hours: data['durationHours'] as int));
                        final dateStr = DateFormat('dd MMM yyyy').format(ts);
                        final timeStr =
                            '${ts.hour.toString().padLeft(2, '0')}:00 - ${end.hour.toString().padLeft(2, '0')}:00';

                        // Check if booking is today
                        final now = DateTime.now();
                        final isToday = ts.year == now.year &&
                            ts.month == now.month &&
                            ts.day == now.day;
                        final isPast = ts.isBefore(now);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border(
                                left: BorderSide(
                                  color: isPast
                                      ? Colors.grey
                                      : (isToday ? Colors.green : Colors.blue),
                                  width: 4,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Facility name + date badge
                                  Row(
                                    children: [
                                      Icon(
                                        _getFacilityIcon(facilityName),
                                        color: Colors.red.shade700,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          facilityName,
                                          style: GoogleFonts.montserrat(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isPast
                                              ? Colors.grey.shade100
                                              : (isToday
                                                  ? Colors.green.shade100
                                                  : Colors.blue.shade100),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          isPast
                                              ? 'PAST'
                                              : (isToday ? 'TODAY' : 'UPCOMING'),
                                          style: GoogleFonts.montserrat(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: isPast
                                                ? Colors.grey.shade700
                                                : (isToday
                                                    ? Colors.green.shade700
                                                    : Colors.blue.shade700),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                  // Date & Time
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today,
                                          size: 16, color: Colors.grey[600]),
                                      const SizedBox(width: 8),
                                      Text(dateStr,
                                          style: GoogleFonts.montserrat(fontSize: 13)),
                                      const SizedBox(width: 16),
                                      Icon(Icons.access_time,
                                          size: 16, color: Colors.grey[600]),
                                      const SizedBox(width: 8),
                                      Text(timeStr,
                                          style: GoogleFonts.montserrat(fontSize: 13)),
                                    ],
                                  ),

                                  const Divider(height: 24),

                                  // Resident info
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: Colors.red.shade100,
                                        child: Text(
                                          residentInfo['fullName']![0].toUpperCase(),
                                          style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              residentInfo['fullName']!,
                                              style: GoogleFonts.montserrat(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              'Unit ${residentInfo['unit']}',
                                              style: GoogleFonts.montserrat(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Phone button
                                      if (residentInfo['phone'] != '-')
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.phone,
                                                  size: 14, color: Colors.grey[700]),
                                              const SizedBox(width: 4),
                                              Text(
                                                residentInfo['phone']!,
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 12,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      // Bottom Navigation
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.red.shade700,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.montserrat(fontSize: 12),
        unselectedLabelStyle: GoogleFonts.montserrat(fontSize: 12),
        onTap: _onNavTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Visitors'),
          BottomNavigationBarItem(icon: Icon(Icons.person_pin), label: 'Tracking'),
          BottomNavigationBarItem(icon: Icon(Icons.event_available), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Maintain'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _filterDate == label;
    return FilterChip(
      label: Text(label, style: GoogleFonts.montserrat(fontSize: 12)),
      selected: isSelected,
      selectedColor: Colors.red.shade100,
      checkmarkColor: Colors.red.shade700,
      onSelected: (_) => setState(() => _filterDate = label),
    );
  }

  IconData _getFacilityIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('pool') || lower.contains('swim')) {
      return Icons.pool;
    } else if (lower.contains('gym')) {
      return Icons.fitness_center;
    } else if (lower.contains('tennis')) {
      return Icons.sports_tennis;
    } else if (lower.contains('basketball')) {
      return Icons.sports_basketball;
    } else if (lower.contains('badminton')) {
      return Icons.sports;
    } else {
      return Icons.event_available;
    }
  }
}
