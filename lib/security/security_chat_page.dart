import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class SecurityChatListPage extends StatelessWidget {
  const SecurityChatListPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final _firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text('Resident Chats',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/security'),
        ),
        backgroundColor: Colors.red.shade700,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('chatRooms')
            .orderBy('lastTimestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading chats',
                  style: GoogleFonts.montserrat(color: Colors.red)),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.forum_outlined,
                      size: 64,
                      color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No active chats',
                      style: GoogleFonts.montserrat(
                        color: Colors.grey,
                        fontSize: 18,
                      )),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await _firestore.collection('chatRooms')
                  .orderBy('lastTimestamp', descending: true)
                  .get();
            },
            child: ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data()! as Map<String, dynamic>;
                final residentId = data['residentId'] as String? ?? '';
                final lastMessage = data['lastMessage'] as String? ?? '';
                final lastTimestamp = data['lastTimestamp'] as Timestamp?;
                final dateStr = lastTimestamp == null
                    ? ''
                    : DateFormat('MMM d, h:mm a')
                    .format(lastTimestamp.toDate().toLocal());

                return FutureBuilder<DocumentSnapshot>(
                  future: _firestore.collection('residents').doc(residentId).get(),
                  builder: (context, residentSnapshot) {
                    if (residentSnapshot.connectionState == ConnectionState.waiting) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey.shade300,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        title: Text('Loading...',
                            style: GoogleFonts.montserrat()),
                      );
                    }

                    if (residentSnapshot.hasError || !residentSnapshot.hasData) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey.shade300,
                          child: const Icon(Icons.error, color: Colors.white),
                        ),
                        title: Text('Unknown Resident',
                            style: GoogleFonts.montserrat()),
                      );
                    }

                    final residentData = residentSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                    final fullName = residentData['fullName'] as String? ?? 'Resident';
                    final firstName = fullName.split(' ').first;
                    final lastNameInitial = fullName.split(' ').length > 1
                        ? fullName.split(' ')[1][0]
                        : '';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.red.shade700,
                        child: Text(
                          fullName.isNotEmpty
                              ? '${firstName[0]}${lastNameInitial.isNotEmpty ? lastNameInitial : ''}'
                              : 'R',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        fullName.isNotEmpty ? fullName : 'Resident',
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        lastMessage.isNotEmpty
                            ? lastMessage.length > 30
                            ? '${lastMessage.substring(0, 30)}...'
                            : lastMessage
                            : 'No messages yet',
                        style: GoogleFonts.montserrat(),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(dateStr, style: GoogleFonts.montserrat(fontSize: 12)),
                          if (lastMessage.isNotEmpty)
                            const Icon(Icons.message, size: 12, color: Colors.grey),
                        ],
                      ),
                      onTap: () {
                        if (residentId.isNotEmpty) {
                          GoRouter.of(context).push('/security/chat/$residentId');
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Invalid resident ID',
                                style: GoogleFonts.montserrat())),
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}