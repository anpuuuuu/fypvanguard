// lib/services/help_assistant_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Help Assistant Service
/// Provides answers to residents' questions about the system using keyword-based responses
class HelpAssistantService {
  // Note: In production, API keys should be stored in Firebase Functions or environment variables
  // This service uses keyword-based fallback responses
  static const String _apiKey = ''; // Leave empty to use fallback responses
  static const String _apiUrl = 'https://api.openai.com/v1/chat/completions';
  
  /// Check if API key is configured
  static bool get hasApiKey => _apiKey.isNotEmpty && _apiKey != 'YOUR_OPENAI_API_KEY';

  /// System knowledge base - contains all feature descriptions
  static String getSystemKnowledge() {
    return '''
You are a help assistant that helps residents use the Vanguard property management application system. Below are all the features and usage instructions:

## System Features Overview

### 1. Visitor Management
- **Feature**: Residents can register visitors, including walk-in visitors and car visitors
- **How to use**:
  - Click the "Visitor" button on the home page
  - Select visitor type: Walk-In or By Car
  - Fill in visitor information: name, contact, license plate (if applicable)
  - After submission, visitor will receive a QR code for entry
  - Security will review visitor requests
- **Visitor status**:
  - pending: Pending approval
  - approved: Approved
  - denied: Denied
  - checked-in: Checked in
  - checked-out: Checked out
  - expired: Expired
- **Parking rules**:
  - Car visitors have a 4-hour parking limit
  - All car visitors must leave after 2 AM
  - Walk-in visitors can stay up to 24 hours

### 2. Facility Booking
- **Feature**: Residents can book community facilities (gym, pool, meeting room, etc.)
- **How to use**:
  - Click the "Facility" button on the home page
  - View available facilities list
  - Select date and time slot
  - Submit booking request
  - System will auto-approve or require security review
- **Booking status**:
  - pending: Pending approval
  - approved: Approved
  - cancelled: Cancelled
  - completed: Completed

### 3. Maintenance Request
- **Feature**: Residents can submit maintenance and repair requests
- **How to use**:
  - Click the "Maintenance" button on the home page
  - Select maintenance category (plumbing, electrical, HVAC, etc.)
  - Describe the issue
  - Upload photos (optional)
  - Submit request
- **Maintenance status**:
  - pending: Pending
  - in_progress: In progress
  - resolved: Resolved
  - rejected: Rejected

### 4. Payment Center
- **Feature**: Residents can view and manage property fee payments
- **How to use**:
  - Click the "Payment Center" card on the home page
  - View pending payments
  - Select payment method (credit card, blockchain, etc.)
  - Complete payment
  - View payment history
- **Payment methods**:
  - Credit card payment
  - Blockchain payment
  - 3D Secure verification

### 5. Chat with Security
- **Feature**: Residents can chat directly with security personnel in real-time
- **How to use**:
  - Click the "Chat with Security" button on the home page
  - Send messages to security
  - Security will reply to your questions
  - Supports message copy and delete functions

### 6. Resident Forum
- **Feature**: Residents can communicate in the community forum
- **How to use**:
  - Click the "Resident Forum" button on the home page
  - View other residents' posts
  - Create new posts
  - Comment and interact

### 7. Emergency
- **Feature**: Residents can report emergencies
- **How to use**:
  - Click the "Emergency" button on the home page
  - Select emergency type
  - Fill in detailed information
  - Submit emergency request
  - Security and admin will receive immediate notification

### 8. Feedback
- **Feature**: Residents can submit feedback to admin and security
- **How to use**:
  - Click the "Feedback" button on the home page
  - Select feedback type
  - Fill in feedback content
  - Submit feedback

### 9. Profile
- **Feature**: Residents can view and edit personal information
- **How to use**:
  - Click the "Profile" button on the home page
  - View personal information (name, contact, email, unit number)
  - Edit name and contact
  - Change password

### 10. Face Registration
- **Feature**: Residents can register face recognition for access control
- **How to use**:
  - In profile page or settings
  - Click "Face Registration"
  - Follow prompts to take face photo
  - After registration, can use face recognition for entry

### 11. My Tenant (Owner only)
- **Feature**: Owners can manage their tenants
- **How to use**:
  - Click the "My Tenant" button on the home page (owner only)
  - View tenant list
  - Register new tenant
  - Manage tenant information

### 12. Announcements
- **Feature**: Residents can view latest announcements on the home page
- **Display location**: Carousel area at the top of home page
- **Content**: Important notices and announcements published by admin

## FAQ

**Q: How to register a visitor?**
A: Click the "Visitor" button on the home page, select visitor type (walk-in or car), fill in visitor information and submit. Visitor will receive a QR code for entry.

**Q: How to book a facility?**
A: Click the "Facility" button on the home page, select the facility to book, choose date and time, then submit booking request.

**Q: How to submit a maintenance request?**
A: Click the "Maintenance" button on the home page, select maintenance category, describe the issue, upload photos (optional), then submit.

**Q: How to pay property fees?**
A: Click the "Payment Center" card on the home page, view pending payments, select payment method and complete payment.

**Q: How to contact security?**
A: Click the "Chat with Security" button on the home page, send messages to security, they will reply as soon as possible.

**Q: What if visitor QR code expires?**
A: If QR code expires, you need to re-register the visitor. QR codes usually have expiration limits.

**Q: How to view my booking history?**
A: On the facility booking page, you can view all your booking records, including approved, pending, and completed bookings.

**Q: How to edit personal information?**
A: Click the "Profile" button on the home page, then click the edit button next to the field you want to modify, enter new information and save.

**Q: How to handle emergencies?**
A: Click the "Emergency" button on the home page, select emergency type, fill in detailed information and submit. Security and admin will receive immediate notification.

**Q: How to view announcements?**
A: Announcements are displayed in the carousel area at the top of the home page, you can swipe left and right to view all announcements.

## Important Notes

1. All visitors must be approved by security before entry
2. Facility bookings may require advance reservation
3. Maintenance requests are processed during business hours
4. Ensure sufficient balance in account for payment
5. For emergencies, use the emergency function immediately, don't wait
6. Face recognition requires good lighting conditions
7. Tenant management is only available to owners

## Role Descriptions

- **tenant**: Tenant, can use all resident features
- **owner**: Owner, can use all resident features, plus manage tenants
- **security**: Security, responsible for reviewing visitors, bookings, and maintenance requests
- **admin**: Admin, responsible for system and user management

Always answer residents' questions in a friendly, professional, and patient manner. If you encounter questions you cannot answer, suggest residents contact admin or security.
''';
  }

  /// Get user context information (optional)
  static Future<Map<String, dynamic>> getUserContext() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {};

      final accountDoc = await FirebaseFirestore.instance
          .collection('accounts')
          .doc(user.uid)
          .get();
      
      final accountData = accountDoc.data() ?? {};
      final residentId = accountData['residentId'] as String?;
      final role = accountData['role'] as String? ?? 'tenant';

      Map<String, dynamic> context = {
        'role': role,
        'userId': user.uid,
      };

      if (residentId != null) {
        final residentDoc = await FirebaseFirestore.instance
            .collection('residents')
            .doc(residentId)
            .get();
        
        final residentData = residentDoc.data() ?? {};
        context['residentName'] = residentData['fullName'] ?? 'Resident';
        context['unitNumber'] = residentData['unitNumber'] ?? 'Unknown';
      }

      return context;
    } catch (e) {
      return {};
    }
  }

  /// Send message and get response
  static Future<String> sendMessage(String userMessage, {List<Map<String, String>>? conversationHistory}) async {
    // If no API key configured, use fallback response
    if (!hasApiKey) {
      return _getFallbackResponse(userMessage);
    }

    try {
      // Get system knowledge and user context
      final systemKnowledge = getSystemKnowledge();
      final userContext = await getUserContext();
      
      // Build context information
      String contextInfo = '';
      if (userContext.isNotEmpty) {
        contextInfo = '\n\nCurrent user information:\n';
        contextInfo += 'Role: ${userContext['role']}\n';
        if (userContext['residentName'] != null) {
          contextInfo += 'Name: ${userContext['residentName']}\n';
        }
        if (userContext['unitNumber'] != null) {
          contextInfo += 'Unit: ${userContext['unitNumber']}\n';
        }
      }

      // Build conversation history
      List<Map<String, String>> messages = [
        {
          'role': 'system',
          'content': systemKnowledge + contextInfo + '\n\nPlease answer residents\' questions in English. Be accurate, friendly, and helpful.',
        },
      ];

      // Add conversation history
      if (conversationHistory != null && conversationHistory.isNotEmpty) {
        messages.addAll(conversationHistory);
      }

      // Add current user message
      messages.add({
        'role': 'user',
        'content': userMessage,
      });

      // Call OpenAI API
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 1000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String;
      } else {
        // If API call fails, return fallback response
        return _getFallbackResponse(userMessage);
      }
    } catch (e) {
      // On error, return fallback response
      return _getFallbackResponse(userMessage);
    }
  }

  /// Fallback response (when API is unavailable)
  static String _getFallbackResponse(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();
    
    if (lowerMessage.contains('visitor')) {
      return 'About Visitor Management:\n\nYou can register visitors by clicking the "Visitor" button on the home page.\n\nSteps:\n1. Select visitor type: Walk-In or By Car\n2. Fill in visitor information: name, contact, license plate (if applicable)\n3. After submission, visitor will receive a QR code for entry\n4. Security will review the visitor request\n\nVisitor status:\n- pending: Pending approval\n- approved: Approved\n- checked-in: Checked in\n- checked-out: Checked out\n\nParking rules:\n- Car visitors have a 4-hour parking limit\n- All car visitors must leave after 2 AM\n- Walk-in visitors can stay up to 24 hours';
    } else if (lowerMessage.contains('facility') || lowerMessage.contains('book') || lowerMessage.contains('booking')) {
      return 'About Facility Booking:\n\nYou can book community facilities (gym, pool, meeting room, etc.) by clicking the "Facility" button on the home page.\n\nSteps:\n1. View available facilities list\n2. Select the facility to book\n3. Choose date and time slot\n4. Submit booking request\n5. System will auto-approve or require security review\n\nBooking status:\n- pending: Pending approval\n- approved: Approved\n- cancelled: Cancelled\n- completed: Completed';
    } else if (lowerMessage.contains('maintenance') || lowerMessage.contains('repair')) {
      return 'About Maintenance Request:\n\nYou can submit maintenance and repair requests by clicking the "Maintenance" button on the home page.\n\nSteps:\n1. Select maintenance category (plumbing, electrical, HVAC, etc.)\n2. Describe the issue\n3. Upload photos (optional)\n4. Select priority\n5. Submit request\n\nMaintenance status:\n- pending: Pending\n- in_progress: In progress\n- resolved: Resolved\n- rejected: Rejected';
    } else if (lowerMessage.contains('payment') || lowerMessage.contains('fee')) {
      return 'About Payment Center:\n\nYou can view and manage property fee payments by clicking the "Payment Center" card on the home page.\n\nSteps:\n1. View pending payments\n2. Select payment method (credit card, blockchain, etc.)\n3. Complete payment\n4. View payment history\n\nPayment methods:\n- Credit card payment\n- Blockchain payment\n- 3D Secure verification';
    } else if (lowerMessage.contains('security') || lowerMessage.contains('chat') || lowerMessage.contains('contact')) {
      return 'About Chat with Security:\n\nYou can chat directly with security personnel in real-time by clicking the "Chat with Security" button on the home page.\n\nFeatures:\n- Real-time messaging\n- Message copy function\n- Message delete function\n- Message read status display\n\nSecurity will reply to your questions and requests as soon as possible.';
    } else if (lowerMessage.contains('emergency')) {
      return 'About Emergency:\n\nYou can report emergencies by clicking the "Emergency" button on the home page.\n\nSteps:\n1. Select emergency type\n2. Fill in detailed information\n3. Submit emergency request\n4. Security and admin will receive immediate notification\n\nImportant: For emergencies, use this function immediately, don\'t wait!';
    } else if (lowerMessage.contains('profile') || lowerMessage.contains('information')) {
      return 'About Profile:\n\nYou can view and edit your personal information by clicking the "Profile" button on the home page.\n\nViewable information:\n- Name\n- Contact number\n- Email (read-only)\n- Unit number (read-only)\n\nEditable information:\n- Name\n- Contact number\n- Password\n\nTo edit: Click the edit button next to the field you want to modify, enter new information and save.';
    } else if (lowerMessage.contains('forum') || lowerMessage.contains('community')) {
      return 'About Resident Forum:\n\nYou can access the community forum by clicking the "Resident Forum" button on the home page.\n\nFeatures:\n- View other residents\' posts\n- Create new posts\n- Comment and interact\n- Participate in community discussions';
    } else if (lowerMessage.contains('feedback')) {
      return 'About Feedback:\n\nYou can submit feedback to admin and security by clicking the "Feedback" button on the home page.\n\nSteps:\n1. Select feedback type\n2. Fill in feedback content\n3. Submit feedback\n\nYour feedback will be taken seriously, and admin and security will handle it promptly.';
    } else if (lowerMessage.contains('face') || lowerMessage.contains('recognition')) {
      return 'About Face Registration:\n\nYou can register face recognition for access control in the profile page or settings.\n\nSteps:\n1. Click "Face Registration"\n2. Follow prompts to take face photo\n3. Complete registration\n4. After registration, you can use face recognition for entry\n\nNote: Good lighting conditions are required for accurate recognition.';
    } else if (lowerMessage.contains('tenant')) {
      return 'About Tenant Management:\n\nThis feature is only available to owners.\n\nFeatures:\n- View tenant list\n- Register new tenant\n- Manage tenant information\n\nIf you are an owner, you will see the "My Tenant" button on the home page.';
    } else if (lowerMessage.contains('announcement') || lowerMessage.contains('notice')) {
      return 'About Announcements:\n\nAnnouncements are displayed in the carousel area at the top of the home page.\n\nFeatures:\n- View latest announcements\n- Swipe left and right to view all announcements\n- Announcements are published by admin\n\nImportant notices and announcements will be displayed here promptly.';
    } else if (lowerMessage.contains('hello') || lowerMessage.contains('hi')) {
      return 'Hello! I\'m the Vanguard Help Assistant, happy to help you!\n\nI can help you with questions about:\n• Visitor management\n• Facility booking\n• Maintenance requests\n• Payment center\n• Chat with security\n• Resident forum\n• Emergency\n• And other system features\n\nFeel free to ask me anything!';
    } else if (lowerMessage.contains('help') || lowerMessage.contains('how')) {
      return 'I can help you understand and use all features of the Vanguard property management system.\n\nYou can ask me:\n• How to register a visitor?\n• How to book a facility?\n• How to submit a maintenance request?\n• How to pay property fees?\n• How to contact security?\n• And other questions about system usage\n\nJust ask directly, and I\'ll provide detailed answers!';
    } else {
      return 'Thank you for your question! While I cannot connect to AI services at the moment, I can provide the following help:\n\n📱 **Ways to get help:**\n1. Check the function buttons on the home page\n2. Use "Chat with Security" to contact security\n3. Submit feedback to admin\n\n🔧 **Common features:**\n• Visitor Management - Register and manage visitors\n• Facility Booking - Book community facilities\n• Maintenance Request - Submit repair requests\n• Payment Center - Pay property fees\n• Chat with Security - Real-time contact with security\n• Resident Forum - Community communication\n• Emergency - Report emergency events\n\nIf you have specific questions, try asking: "How to register a visitor?" or "How to book a facility?" etc.';
    }
  }
}
