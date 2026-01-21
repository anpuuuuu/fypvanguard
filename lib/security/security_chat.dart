import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class SecurityChatPage extends StatefulWidget {
  final String residentId;
  const SecurityChatPage({Key? key, required this.residentId}) : super(key: key);

  @override
  _SecurityChatPageState createState() => _SecurityChatPageState();
}

class _SecurityChatPageState extends State<SecurityChatPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _msgController = TextEditingController();
  late ScrollController _scrollController;
  String? _securityId;
  bool _loadingSecurityId = true;
  bool _sendingMessage = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadSecurityId();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
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
      });

      await _firestore.collection('chatRooms').doc(widget.residentId).set({
        'residentId': widget.residentId,
        'lastMessage': text,
        'lastTimestamp': FieldValue.serverTimestamp(),
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

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate().toLocal();  // Added .toLocal()
    return DateFormat('h:mm a').format(date);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _msgController.dispose();
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        title: Text('Chat with Resident', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .where('roomId', isEqualTo: widget.residentId)
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading messages',
                        style: GoogleFonts.montserrat(color: Colors.red)),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Text('No messages yet. Start chatting!',
                        style: GoogleFonts.montserrat(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == _securityId;

                    return Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.red.shade700 : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['message'] ?? '',
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black87,
                                  fontSize: 16,
                                  fontFamily: GoogleFonts.montserrat().fontFamily,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTimestamp(data['timestamp'] as Timestamp?),
                                style: TextStyle(
                                  color: isMe ? Colors.white70 : Colors.black54,
                                  fontSize: 10,
                                  fontFamily: GoogleFonts.montserrat().fontFamily,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      style: GoogleFonts.montserrat(),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: GoogleFonts.montserrat(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        fillColor: Colors.grey.shade200,
                        filled: true,
                        contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.red.shade700,
                    child: IconButton(
                      icon: _sendingMessage
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendingMessage ? null : _sendMessage,
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