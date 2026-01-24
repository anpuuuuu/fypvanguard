import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class SecurityChatPage extends StatefulWidget {
  final String residentId;
  const SecurityChatPage({Key? key, required this.residentId}) : super(key: key);

  @override
  _SecurityChatPageState createState() => _SecurityChatPageState();
}

class _SecurityChatPageState extends State<SecurityChatPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  late ScrollController _scrollController;
  String? _securityId;
  bool _loadingSecurityId = true;
  bool _sendingMessage = false;
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadSecurityId();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
      // Mark messages as read when opening chat
      _markAsRead();
    });
  }

  Future<void> _loadSecurityId() async {
    try {
      final snap = await _firestore
          .collection('accounts')
          .where('role', isEqualTo: 'security')
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      setState(() {
        _securityId = snap.docs.isNotEmpty ? snap.docs.first.id : '';
        _loadingSecurityId = false;
      });
    } catch (e) {
      setState(() {
        _securityId = '';
        _loadingSecurityId = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading security account: ${e.toString()}')),
        );
      }
    }
  }


  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _securityId == null || _securityId == '') return;

    setState(() => _sendingMessage = true);

    try {
      await _firestore.collection('chats').add({
        'roomId': widget.residentId,
        'senderId': _securityId,
        'message': text,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      await _firestore.collection('chatRooms').doc(widget.residentId).set({
        'residentId': widget.residentId,
        'lastMessage': text,
        'lastTimestamp': FieldValue.serverTimestamp(),
        'unreadCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      _msgController.clear();

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sendingMessage = false);
      }
    }
  }

  Future<void> _markAsRead() async {
    try {
      final unreadMessages = await _firestore
          .collection('chats')
          .where('roomId', isEqualTo: widget.residentId)
          .where('senderId', isNotEqualTo: _securityId)
          .where('read', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'read': true});
      }

      await batch.commit();

      // Reset unread count
      await _firestore.collection('chatRooms').doc(widget.residentId).update({
        'unreadCount': 0,
      });
    } catch (e) {
      // Silent fail
    }
  }

  void _showMessageOptions(String messageId, String message, bool isMyMessage) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.blue),
              title: Text('Copy', style: GoogleFonts.montserrat()),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Message copied', style: GoogleFonts.montserrat()),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
            if (isMyMessage)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text('Delete', style: GoogleFonts.montserrat()),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(messageId);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessage(String messageId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Message', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to delete this message?', style: GoogleFonts.montserrat()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.montserrat()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.montserrat(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('chats').doc(messageId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Message deleted', style: GoogleFonts.montserrat()),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete message', style: GoogleFonts.montserrat())),
          );
        }
      }
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate().toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    
    if (messageDate == today) {
      return DateFormat('h:mm a').format(date);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${DateFormat('h:mm a').format(date)}';
    } else {
      return DateFormat('MMM d, h:mm a').format(date);
    }
  }

  Future<Map<String, String>> _fetchResidentInfo(String residentId) async {
    try {
      final doc = await _firestore.collection('residents').doc(residentId).get();
      if (!doc.exists) {
        return {'fullName': 'Resident', 'unit': 'N/A'};
      }
      final data = doc.data()!;
      return {
        'fullName': data['fullName'] as String? ?? 'Resident',
        'unit': data['unitNumber'] as String? ?? 'N/A',
      };
    } catch (e) {
      return {'fullName': 'Resident', 'unit': 'N/A'};
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _msgController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingSecurityId) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.red.shade700,
          title: Text('Chat with Resident', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_securityId == '') {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.red.shade700,
          title: Text('Chat with Resident', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Text('No active security account found',
              style: GoogleFonts.montserrat(color: Colors.red)),
        ),
      );
    }

    return FutureBuilder<Map<String, String>>(
      future: _fetchResidentInfo(widget.residentId),
      builder: (context, residentSnapshot) {
        final residentInfo = residentSnapshot.data ?? {'fullName': 'Resident', 'unit': 'N/A'};
        
        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            backgroundColor: Colors.red.shade700,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  residentInfo['fullName']!,
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Unit ${residentInfo['unit']}',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            centerTitle: false,
            actions: [
              IconButton(
                icon: Icon(_isSearching ? Icons.close : Icons.search),
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchQuery = '';
                      _searchController.clear();
                    }
                  });
                },
              ),
            ],
          ),
          body: Column(
            children: [
              if (_isSearching)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search messages...',
                      prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    style: GoogleFonts.montserrat(),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                  ),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('chats')
                        .where('roomId', isEqualTo: widget.residentId)
                        .orderBy('timestamp')
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
                                'Error loading messages',
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
                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                'No messages yet',
                                style: GoogleFonts.montserrat(
                                  color: Colors.grey[600],
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Start the conversation!',
                                style: GoogleFonts.montserrat(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Filter messages by search query
                      final filteredDocs = _searchQuery.isEmpty
                          ? docs
                          : docs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final message = data['message']?.toString().toLowerCase() ?? '';
                              return message.contains(_searchQuery);
                            }).toList();

                      if (_searchQuery.isNotEmpty && filteredDocs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                'No messages found',
                                style: GoogleFonts.montserrat(
                                  color: Colors.grey[600],
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final data = filteredDocs[index].data() as Map<String, dynamic>;
                          final isMe = data['senderId'] == _securityId;
                          final message = data['message']?.toString() ?? '';
                          final timestamp = data['timestamp'] as Timestamp?;
                          
                          // Check if this is a new day (only show if not searching)
                          bool showDateSeparator = false;
                          if (!_isSearching) {
                            if (index > 0) {
                              final prevData = filteredDocs[index - 1].data() as Map<String, dynamic>;
                              final prevTimestamp = prevData['timestamp'] as Timestamp?;
                              if (timestamp != null && prevTimestamp != null) {
                                final prevDate = prevTimestamp.toDate().toLocal();
                                final currentDate = timestamp.toDate().toLocal();
                                if (DateTime(prevDate.year, prevDate.month, prevDate.day) !=
                                    DateTime(currentDate.year, currentDate.month, currentDate.day)) {
                                  showDateSeparator = true;
                                }
                              }
                            } else {
                              showDateSeparator = true;
                            }
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (showDateSeparator && timestamp != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        DateFormat('MMMM d, yyyy').format(timestamp.toDate().toLocal()),
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              Align(
                                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                child: GestureDetector(
                                  onLongPress: () => _showMessageOptions(
                                    filteredDocs[index].id,
                                    message,
                                    isMe,
                                  ),
                                  child: Container(
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                                    ),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isMe ? Colors.red.shade700 : Colors.white,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(18),
                                        topRight: const Radius.circular(18),
                                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                                        bottomRight: Radius.circular(isMe ? 4 : 18),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          message,
                                          style: GoogleFonts.montserrat(
                                            color: isMe ? Colors.white : Colors.grey[900],
                                            fontSize: 15,
                                            height: 1.4,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _formatTimestamp(timestamp),
                                              style: GoogleFonts.montserrat(
                                                color: isMe ? Colors.white70 : Colors.grey[600],
                                                fontSize: 11,
                                              ),
                                            ),
                                            if (isMe) ...[
                                              const SizedBox(width: 4),
                                              Icon(
                                                data['read'] == true
                                                    ? Icons.done_all
                                                    : Icons.done,
                                                size: 14,
                                                color: data['read'] == true
                                                    ? Colors.blue[300]
                                                    : Colors.white70,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: TextField(
                              controller: _msgController,
                              style: GoogleFonts.montserrat(fontSize: 15),
                              maxLines: null,
                              textInputAction: TextInputAction.newline,
                              decoration: InputDecoration(
                                hintText: 'Type a message...',
                                hintStyle: GoogleFonts.montserrat(
                                  color: Colors.grey[500],
                                  fontSize: 15,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            shape: BoxShape.circle,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _sendingMessage ? null : _sendMessage,
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                width: 48,
                                height: 48,
                                padding: const EdgeInsets.all(12),
                                child: _sendingMessage
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.send_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}