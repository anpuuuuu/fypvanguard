// lib/user/help_assistant_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../services/help_assistant_service.dart';

class HelpAssistantPage extends StatefulWidget {
  const HelpAssistantPage({Key? key}) : super(key: key);

  @override
  _HelpAssistantPageState createState() => _HelpAssistantPageState();
}

class _HelpAssistantPageState extends State<HelpAssistantPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _userId;
  String? _residentName;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _addWelcomeMessage();
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          context.go('/login');
        }
        return;
      }

      setState(() {
        _userId = user.uid;
      });

      // Get resident information
      final accountDoc = await FirebaseFirestore.instance
          .collection('accounts')
          .doc(user.uid)
          .get();
      
      final accountData = accountDoc.data() ?? {};
      final residentId = accountData['residentId'] as String?;

      if (residentId != null) {
        final residentDoc = await FirebaseFirestore.instance
            .collection('residents')
            .doc(residentId)
            .get();
        
        final residentData = residentDoc.data() ?? {};
        setState(() {
          _residentName = residentData['fullName'] as String?;
        });
      }
    } catch (e) {
      // Silently handle error
    }
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add(ChatMessage(
        text: 'Hello! I\'m the Vanguard Help Assistant, and I can help you understand and use all the system features.\n\nI can help you with questions about:\n• Visitor Management\n• Facility Booking\n• Maintenance Requests\n• Payment Center\n• Chat with Security\n• And other system features\n\nFeel free to ask me anything!',
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    
    if (messageDate == today) {
      return DateFormat('h:mm a').format(timestamp);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${DateFormat('h:mm a').format(timestamp)}';
    } else {
      return DateFormat('MMM d, h:mm a').format(timestamp);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    // Add user message
    final userMessage = ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      // Build conversation history
      final conversationHistory = _messages
          .where((m) => m.text != _messages.first.text) // Exclude welcome message
          .map((m) => <String, String>{
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.text,
              })
          .toList();

      // Call help assistant service
      final response = await HelpAssistantService.sendMessage(
        text,
        conversationHistory: conversationHistory,
      );

      // Add assistant reply
      setState(() {
        _messages.add(ChatMessage(
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'Sorry, an error occurred. Please try again later or contact admin.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: ${e.toString()}'),
            backgroundColor: Colors.red.shade300,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showQuickQuestions() {
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
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Quick Questions',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(),
            _buildQuickQuestionItem('How to register a visitor?', () {
              Navigator.pop(context);
              _messageController.text = 'How to register a visitor?';
              _sendMessage();
            }),
            _buildQuickQuestionItem('How to book a facility?', () {
              Navigator.pop(context);
              _messageController.text = 'How to book a facility?';
              _sendMessage();
            }),
            _buildQuickQuestionItem('How to submit a maintenance request?', () {
              Navigator.pop(context);
              _messageController.text = 'How to submit a maintenance request?';
              _sendMessage();
            }),
            _buildQuickQuestionItem('How to pay property fees?', () {
              Navigator.pop(context);
              _messageController.text = 'How to pay property fees?';
              _sendMessage();
            }),
            _buildQuickQuestionItem('How to contact security?', () {
              Navigator.pop(context);
              _messageController.text = 'How to contact security?';
              _sendMessage();
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickQuestionItem(String question, VoidCallback onTap) {
    return ListTile(
      leading: Icon(Icons.help_outline, color: Colors.red.shade700),
      title: Text(
        question,
        style: GoogleFonts.montserrat(),
      ),
      onTap: onTap,
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: Icon(Icons.help_outline, color: Colors.red.shade700, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Help Assistant',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  HelpAssistantService.hasApiKey ? 'Real AI · Here to help' : 'Here to help',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/user'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showQuickQuestions,
            tooltip: 'Quick Questions',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.help_outline, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Start Conversation',
                          style: GoogleFonts.montserrat(
                            color: Colors.grey[600],
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ask me anything about the system',
                          style: GoogleFonts.montserrat(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        // Show loading indicator
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade700),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Thinking...',
                                  style: GoogleFonts.montserrat(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final message = _messages[index];
                      final showDateSeparator = index == 0 ||
                          (index > 0 &&
                              DateTime(
                                    _messages[index - 1].timestamp.year,
                                    _messages[index - 1].timestamp.month,
                                    _messages[index - 1].timestamp.day,
                                  ) !=
                                  DateTime(
                                    message.timestamp.year,
                                    message.timestamp.month,
                                    message.timestamp.day,
                                  ));

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showDateSeparator)
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
                                    DateFormat('MMMM d, yyyy').format(message.timestamp),
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
                            alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: GestureDetector(
                              onLongPress: () {
                                if (!message.isUser) return;
                                Clipboard.setData(ClipboardData(text: message.text));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Message copied', style: GoogleFonts.montserrat()),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                                ),
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: message.isUser ? Colors.red.shade700 : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(18),
                                    topRight: const Radius.circular(18),
                                    bottomLeft: Radius.circular(message.isUser ? 18 : 4),
                                    bottomRight: Radius.circular(message.isUser ? 4 : 18),
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
                                      message.text,
                                      style: GoogleFonts.montserrat(
                                        color: message.isUser ? Colors.white : Colors.grey[900],
                                        fontSize: 15,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTimestamp(message.timestamp),
                                      style: GoogleFonts.montserrat(
                                        color: message.isUser ? Colors.white70 : Colors.grey[600],
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
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
                          controller: _messageController,
                          style: GoogleFonts.montserrat(fontSize: 15),
                          maxLines: null,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: 'Type your question...',
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
                          onTap: _isLoading ? null : _sendMessage,
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            width: 48,
                            height: 48,
                            padding: const EdgeInsets.all(12),
                            child: _isLoading
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
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
