import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class SecurityChatListPage extends StatefulWidget {
  const SecurityChatListPage({Key? key}) : super(key: key);

  @override
  State<SecurityChatListPage> createState() => _SecurityChatListPageState();
}

class _SecurityChatListPageState extends State<SecurityChatListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _firestore = FirebaseFirestore.instance;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Messages from Residents',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/security'),
        ),
        backgroundColor: Colors.red.shade700,
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search residents...',
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                hintStyle: GoogleFonts.montserrat(color: Colors.grey[500]),
              ),
              style: GoogleFonts.montserrat(),
            ),
          ),
          // Chat list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chatRooms')
                  .orderBy('lastTimestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading chats',
                          style: GoogleFonts.montserrat(
                            color: Colors.red,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                final filteredDocs = _searchQuery.isEmpty
                    ? docs
                    : docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final residentId = data['residentId'] as String? ?? '';
                        // We'll filter by resident name in the FutureBuilder
                        return true;
                      }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isEmpty
                              ? Icons.chat_bubble_outline
                              : Icons.search_off,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No active chats'
                              : 'No residents found',
                          style: GoogleFonts.montserrat(
                            color: Colors.grey[600],
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_searchQuery.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Messages from residents will appear here',
                              style: GoogleFonts.montserrat(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await _firestore
                        .collection('chatRooms')
                        .orderBy('lastTimestamp', descending: true)
                        .get();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final data = filteredDocs[index].data() as Map<String, dynamic>;
                      final residentId = data['residentId'] as String? ?? '';
                      final lastMessage = data['lastMessage'] as String? ?? '';
                      final lastTimestamp = data['lastTimestamp'] as Timestamp?;
                      
                      String dateStr = '';
                      if (lastTimestamp != null) {
                        final date = lastTimestamp.toDate().toLocal();
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        final messageDate = DateTime(date.year, date.month, date.day);
                        
                        if (messageDate == today) {
                          dateStr = DateFormat('h:mm a').format(date);
                        } else if (messageDate == today.subtract(const Duration(days: 1))) {
                          dateStr = 'Yesterday';
                        } else {
                          dateStr = DateFormat('MMM d').format(date);
                        }
                      }

                      return FutureBuilder<DocumentSnapshot>(
                        future: _firestore.collection('residents').doc(residentId).get(),
                        builder: (context, residentSnapshot) {
                          if (residentSnapshot.connectionState == ConnectionState.waiting) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.grey[200],
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          height: 16,
                                          width: 120,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          height: 12,
                                          width: 200,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (residentSnapshot.hasError || !residentSnapshot.hasData) {
                            return const SizedBox.shrink();
                          }

                          final residentData =
                              residentSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                          final fullName = residentData['fullName'] as String? ?? 'Resident';
                          final unitNumber = residentData['unitNumber'] as String? ?? 'N/A';
                          
                          // Filter by search query
                          if (_searchQuery.isNotEmpty) {
                            if (!fullName.toLowerCase().contains(_searchQuery) &&
                                !unitNumber.toLowerCase().contains(_searchQuery)) {
                              return const SizedBox.shrink();
                            }
                          }

                          // Get unread count
                          final unreadCount = data['unreadCount'] as int? ?? 0;

                          final firstName = fullName.split(' ').first;
                          final lastNameInitial = fullName.split(' ').length > 1
                              ? fullName.split(' ')[1][0]
                              : '';

                          return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      if (residentId.isNotEmpty) {
                                        GoRouter.of(context).push('/security/chat/$residentId');
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Invalid resident ID',
                                              style: GoogleFonts.montserrat(),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 28,
                                            backgroundColor: Colors.red.shade700,
                                            child: Text(
                                              fullName.isNotEmpty
                                                  ? '${firstName[0]}${lastNameInitial.isNotEmpty ? lastNameInitial : ''}'
                                                  : 'R',
                                              style: GoogleFonts.montserrat(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        fullName.isNotEmpty ? fullName : 'Resident',
                                                        style: GoogleFonts.montserrat(
                                                          fontWeight: FontWeight.w700,
                                                          fontSize: 16,
                                                          color: Colors.grey[900],
                                                        ),
                                                      ),
                                                    ),
                                                    if (dateStr.isNotEmpty)
                                                      Text(
                                                        dateStr,
                                                        style: GoogleFonts.montserrat(
                                                          fontSize: 12,
                                                          color: Colors.grey[500],
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        lastMessage.isNotEmpty
                                                            ? (lastMessage.length > 40
                                                                ? '${lastMessage.substring(0, 40)}...'
                                                                : lastMessage)
                                                            : 'No messages yet',
                                                        style: GoogleFonts.montserrat(
                                                          fontSize: 14,
                                                          color: unreadCount > 0
                                                              ? Colors.grey[900]
                                                              : Colors.grey[600],
                                                          fontWeight: unreadCount > 0
                                                              ? FontWeight.w600
                                                              : FontWeight.normal,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    if (unreadCount > 0)
                                                      Container(
                                                        margin: const EdgeInsets.only(left: 8),
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.red.shade700,
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                        child: Text(
                                                          unreadCount > 99 ? '99+' : '$unreadCount',
                                                          style: GoogleFonts.montserrat(
                                                            fontSize: 11,
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Unit $unitNumber',
                                                  style: GoogleFonts.montserrat(
                                                    fontSize: 12,
                                                    color: Colors.grey[500],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}