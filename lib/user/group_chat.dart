import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'comments_page.dart'; // Import the CommentsPage below (step 2)

class GroupChatPage extends StatefulWidget {
  const GroupChatPage({Key? key}) : super(key: key);

  @override
  _GroupChatPageState createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _postController = TextEditingController();

  Future<String> _getUserName(String userId) async {
    final doc = await _firestore.collection('residents').doc(userId).get();
    final data = doc.data();
    return data?['fullName'] ?? 'Unknown';
  }

  Future<void> _addPost() async {
    final content = _postController.text.trim();
    if (content.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _firestore.collection('posts').add({
      'authorId': user.uid,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
    });

    _postController.clear();
  }

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  Widget _buildPostTile(DocumentSnapshot postDoc) {
    final data = postDoc.data()! as Map<String, dynamic>;
    final content = data['content'] ?? '';
    final authorId = data['authorId'] ?? '';
    final timestamp = data['createdAt'] as Timestamp?;

    return FutureBuilder<String>(
      future: _getUserName(authorId),
      builder: (context, snapshot) {
        final authorName = snapshot.data ?? 'Loading...';
        final timeStr = timestamp != null
            ? timestamp.toDate().toLocal().toString().split('.')[0]
            : '...';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            title: Text(authorName, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(content, style: GoogleFonts.montserrat()),
                const SizedBox(height: 6),
                Text(timeStr, style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey)),
              ],
            ),
            isThreeLine: true,
            trailing: IconButton(
              icon: const Icon(Icons.comment),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => CommentsPage(postId: postDoc.id),
                ));
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Community Chat', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/user'),
        ),
        backgroundColor: Colors.red.shade700,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _postController,
                    decoration: InputDecoration(
                      hintText: 'Write a new post...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    style: GoogleFonts.montserrat(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                  onPressed: _addPost,
                  child: Text('Post', style: GoogleFonts.montserrat(color: Colors.white)),
                )
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('posts').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(child: Text('No posts yet.', style: GoogleFonts.montserrat(color: Colors.grey)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) => _buildPostTile(docs[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
