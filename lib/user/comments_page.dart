import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class CommentsPage extends StatefulWidget {
  final String postId;
  const CommentsPage({Key? key, required this.postId}) : super(key: key);

  @override
  _CommentsPageState createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Future<Map<String, dynamic>> _getUserInfo(String userId) async {
    try {
      final residentDoc = await _firestore.collection('residents').doc(userId).get();
      final accountDoc = await _firestore.collection('accounts').doc(userId).get();
      
      final residentData = residentDoc.data();
      final accountData = accountDoc.data();
      
      return {
        'name': residentData?['fullName'] ?? accountData?['username']?.split('@').first ?? 'Unknown',
        'role': accountData?['role'] ?? 'user',
        'unit': residentData?['unitNumber'] ?? '',
      };
    } catch (e) {
      return {'name': 'Unknown', 'role': 'user', 'unit': ''};
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a comment')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .add({
        'authorId': user.uid,
        'content': text,
        'createdAt': FieldValue.serverTimestamp(),
        'edited': false,
        'editedAt': null,
      });

      // Update comments count
      await _firestore.collection('posts').doc(widget.postId).update({
        'commentsCount': FieldValue.increment(1),
      });

      _commentController.clear();
      
      // Scroll to bottom
      if (_scrollController.hasClients) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add comment: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Comment', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this comment?',
            style: GoogleFonts.montserrat()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.montserrat()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: GoogleFonts.montserrat(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .doc(commentId)
            .delete();

        // Update comments count
        await _firestore.collection('posts').doc(widget.postId).update({
          'commentsCount': FieldValue.increment(-1),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comment deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete comment: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _editComment(String commentId, String currentContent) async {
    final editController = TextEditingController(text: currentContent);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Comment', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: editController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Edit your comment...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          style: GoogleFonts.montserrat(),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.montserrat()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, editController.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: Text('Save', style: GoogleFonts.montserrat(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await _firestore
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .doc(commentId)
            .update({
          'content': result,
          'edited': true,
          'editedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comment updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update comment: ${e.toString()}')),
          );
        }
      }
    }
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    
    final now = DateTime.now();
    final commentTime = timestamp.toDate().toLocal();
    final difference = now.difference(commentTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM d, yyyy').format(commentTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return Colors.blue;
      case 'tenant':
        return Colors.green;
      case 'security':
        return Colors.orange;
      case 'admin':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildCommentTile(DocumentSnapshot commentDoc) {
    final data = commentDoc.data()! as Map<String, dynamic>;
    final content = data['content'] ?? '';
    final authorId = data['authorId'] ?? '';
    final timestamp = data['createdAt'] as Timestamp?;
    final isEdited = data['edited'] ?? false;
    
    final currentUser = FirebaseAuth.instance.currentUser;
    final isAuthor = currentUser?.uid == authorId;

    return FutureBuilder<Map<String, dynamic>>(
      future: _getUserInfo(authorId),
      builder: (context, snapshot) {
        final userInfo = snapshot.data ?? {'name': 'Loading...', 'role': 'user', 'unit': ''};
        final authorName = userInfo['name'] ?? 'Unknown';
        final role = userInfo['role'] ?? 'user';
        final unit = userInfo['unit'] ?? '';
        final roleColor = _getRoleColor(role);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: roleColor,
                child: Text(
                  authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          authorName,
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: roleColor.withOpacity(0.5)),
                          ),
                          child: Text(
                            role.toUpperCase(),
                            style: GoogleFonts.montserrat(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: roleColor,
                            ),
                          ),
                        ),
                        if (unit.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            '• Unit $unit',
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      content,
                      style: GoogleFonts.montserrat(fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _formatTime(timestamp),
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (isEdited) ...[
                          const SizedBox(width: 6),
                          Text(
                            '• Edited',
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              color: Colors.grey[500],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (isAuthor)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () => _editComment(commentDoc.id, content),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Icon(Icons.edit, size: 16, color: Colors.blue[700]),
                                ),
                              ),
                              InkWell(
                                onTap: () => _deleteComment(commentDoc.id),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Icon(Icons.delete, size: 16, color: Colors.red[700]),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
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
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: GoogleFonts.montserrat(color: Colors.red),
                    ),
                  );
                }
                
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.comment_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No comments yet. Be the first to comment!',
                          style: GoogleFonts.montserrat(color: Colors.grey[600], fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) => _buildCommentTile(docs[index]),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      style: GoogleFonts.montserrat(),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _addComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.red.shade700,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _addComment,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
