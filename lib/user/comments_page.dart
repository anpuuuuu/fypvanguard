import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CommentsPage extends StatefulWidget {
  final String postId;
  const CommentsPage({Key? key, required this.postId}) : super(key: key);

  @override
  _CommentsPageState createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _commentController = TextEditingController();

  Future<String> _getUserName(String userId) async {
    final doc = await _firestore.collection('residents').doc(userId).get();
    final data = doc.data();
    return data?['fullName'] ?? 'Unknown';
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _firestore
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .add({
      'authorId': user.uid,
      'content': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    _commentController.clear();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Widget _buildCommentTile(DocumentSnapshot commentDoc) {
    final data = commentDoc.data()! as Map<String, dynamic>;
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

        return ListTile(
          title: Text(authorName, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(content, style: GoogleFonts.montserrat()),
              const SizedBox(height: 6),
              Text(timeStr, style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey)),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Comments', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red.shade700,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('createdAt')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(child: Text('No comments yet.', style: GoogleFonts.montserrat(color: Colors.grey)));
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) => _buildCommentTile(docs[index]),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    style: GoogleFonts.montserrat(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                  onPressed: _addComment,
                  child: Text('Post', style: GoogleFonts.montserrat(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
