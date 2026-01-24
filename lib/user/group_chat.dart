import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'comments_page.dart';

class GroupChatPage extends StatefulWidget {
  const GroupChatPage({Key? key}) : super(key: key);

  @override
  _GroupChatPageState createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _postController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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

  Future<void> _addPost() async {
    final content = _postController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some content')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('posts').add({
        'authorId': user.uid,
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': <String>[],
        'likesCount': 0,
        'commentsCount': 0,
        'edited': false,
        'editedAt': null,
      });

      _postController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post published successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to publish post: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _toggleLike(String postId, List<dynamic> currentLikes) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final likes = List<String>.from(currentLikes);
    final isLiked = likes.contains(user.uid);

    try {
      if (isLiked) {
        likes.remove(user.uid);
      } else {
        likes.add(user.uid);
      }

      await _firestore.collection('posts').doc(postId).update({
        'likes': likes,
        'likesCount': likes.length,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update like: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deletePost(String postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Post', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this post? This action cannot be undone.',
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
        // Delete all comments first
        final commentsSnapshot = await _firestore
            .collection('posts')
            .doc(postId)
            .collection('comments')
            .get();
        
        final batch = _firestore.batch();
        for (var doc in commentsSnapshot.docs) {
          batch.delete(doc.reference);
        }
        batch.delete(_firestore.collection('posts').doc(postId));
        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete post: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _editPost(String postId, String currentContent) async {
    final editController = TextEditingController(text: currentContent);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Post', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: editController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Edit your post...',
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
        await _firestore.collection('posts').doc(postId).update({
          'content': result,
          'edited': true,
          'editedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update post: ${e.toString()}')),
          );
        }
      }
    }
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    
    final now = DateTime.now();
    final postTime = timestamp.toDate().toLocal();
    final difference = now.difference(postTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM d, yyyy').format(postTime);
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

  Widget _buildPostTile(DocumentSnapshot postDoc) {
    final data = postDoc.data()! as Map<String, dynamic>;
    final content = data['content'] ?? '';
    final authorId = data['authorId'] ?? '';
    final timestamp = data['createdAt'] as Timestamp?;
    final editedAt = data['editedAt'] as Timestamp?;
    final isEdited = data['edited'] ?? false;
    final likes = List<String>.from(data['likes'] ?? []);
    final likesCount = data['likesCount'] ?? likes.length;
    final commentsCount = data['commentsCount'] ?? 0;
    
    final currentUser = FirebaseAuth.instance.currentUser;
    final isAuthor = currentUser?.uid == authorId;
    final isLiked = currentUser != null && likes.contains(currentUser.uid);

    return FutureBuilder<Map<String, dynamic>>(
      future: _getUserInfo(authorId),
      builder: (context, snapshot) {
        final userInfo = snapshot.data ?? {'name': 'Loading...', 'role': 'user', 'unit': ''};
        final authorName = userInfo['name'] ?? 'Unknown';
        final role = userInfo['role'] ?? 'user';
        final unit = userInfo['unit'] ?? '';
        final roleColor = _getRoleColor(role);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: roleColor,
                      child: Text(
                        authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
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
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: roleColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: roleColor.withOpacity(0.5)),
                                ),
                                child: Text(
                                  role.toUpperCase(),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: roleColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (unit.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Unit $unit',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                _formatTime(timestamp),
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (isEdited) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '• Edited',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isAuthor)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _editPost(postDoc.id, content);
                          } else if (value == 'delete') {
                            _deletePost(postDoc.id);
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                const Icon(Icons.edit, size: 18, color: Colors.blue),
                                const SizedBox(width: 8),
                                Text('Edit', style: GoogleFonts.montserrat()),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(Icons.delete, size: 18, color: Colors.red),
                                const SizedBox(width: 8),
                                Text('Delete', style: GoogleFonts.montserrat(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  content,
                  style: GoogleFonts.montserrat(fontSize: 15, height: 1.5),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    // Like button
                    InkWell(
                      onTap: () => _toggleLike(postDoc.id, likes),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              color: isLiked ? Colors.red : Colors.grey[600],
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              likesCount.toString(),
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isLiked ? Colors.red : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Comment button
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CommentsPage(postId: postDoc.id),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.comment_outlined, color: Colors.grey[600], size: 20),
                            const SizedBox(width: 6),
                            Text(
                              commentsCount.toString(),
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _postController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Resident Forum', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/user'),
        ),
        backgroundColor: Colors.red.shade700,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_searchQuery.isNotEmpty ? Icons.close : Icons.search),
            onPressed: () {
              if (_searchQuery.isNotEmpty) {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                });
              } else {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text('Search Posts', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                    content: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by content...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.search),
                      ),
                      style: GoogleFonts.montserrat(),
                      autofocus: true,
                      onSubmitted: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase();
                        });
                        Navigator.pop(context);
                      },
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel', style: GoogleFonts.montserrat()),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _searchQuery = _searchController.text.toLowerCase();
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                        child: Text('Search', style: GoogleFonts.montserrat(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar (if searching)
          if (_searchQuery.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Searching: "$_searchQuery"',
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                    child: Text('Clear', style: GoogleFonts.montserrat()),
                  ),
                ],
              ),
            ),
          
          // Post input
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _postController,
                    decoration: InputDecoration(
                      hintText: 'Share something with the community...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    style: GoogleFonts.montserrat(),
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _addPost,
                  child: Text('Post', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          
          // Posts list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('posts')
                  .orderBy('createdAt', descending: true)
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
                
                // Filter by search query
                final filteredDocs = _searchQuery.isEmpty
                    ? docs
                    : docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final content = (data['content'] ?? '').toString().toLowerCase();
                        return content.contains(_searchQuery);
                      }).toList();
                
                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.forum_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? 'No posts yet. Be the first to share!' : 'No posts found',
                          style: GoogleFonts.montserrat(color: Colors.grey[600], fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }
                
                return RefreshIndicator(
                  onRefresh: () async {
                    // Force refresh by rebuilding
                    setState(() {});
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) => _buildPostTile(filteredDocs[index]),
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
