// lib/user/visitor_qr_page.dart
// 访客 QR 码查看和分享页面

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class VisitorQrPage extends StatelessWidget {
  final String visitorId;
  
  const VisitorQrPage({Key? key, required this.visitorId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Visitor Pass',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).pop(),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('visitors')
            .doc(visitorId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('Visitor not found', style: GoogleFonts.montserrat(color: Colors.grey)),
                ],
              ),
            );
          }
          
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final visitorName = data['visitorName'] as String? ?? 'Unknown';
          final entryType = data['entryType'] as String? ?? '';
          final status = data['status'] as String? ?? '';
          final qrCode = data['qrCode'] as String?;
          final qrExpiresAt = (data['qrExpiresAt'] as Timestamp?)?.toDate();
          final vehiclePlate = data['vehiclePlate'] as String?;
          
          final isExpired = qrExpiresAt != null && DateTime.now().isAfter(qrExpiresAt);
          final isValid = qrCode != null && !isExpired && 
              (status == 'approved' || status == 'checked-in');
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // QR 码卡片
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // 访客名称
                        Text(
                          visitorName,
                          style: GoogleFonts.montserrat(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // 入场类型标签
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: entryType == 'walk-in' 
                                ? Colors.blue.shade100 
                                : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            entryType == 'walk-in' ? 'WALK-IN' : 'BY CAR',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: entryType == 'walk-in' 
                                  ? Colors.blue.shade700 
                                  : Colors.orange.shade700,
                            ),
                          ),
                        ),
                        
                        if (vehiclePlate != null && vehiclePlate.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Plate: $vehiclePlate',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 24),
                        
                        // QR 码
                        if (isValid && qrCode != null) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: QrImageView(
                              data: qrCode,
                              version: QrVersions.auto,
                              size: 200,
                              backgroundColor: Colors.white,
                              errorCorrectionLevel: QrErrorCorrectLevel.H,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // 有效期
                          if (qrExpiresAt != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.access_time, size: 16, color: Colors.green.shade700),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Valid until: ${DateFormat('dd MMM yyyy, HH:mm').format(qrExpiresAt)}',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ] else if (status == 'pending') ...[
                          // 等待审批
                          Container(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(Icons.hourglass_empty, size: 64, color: Colors.orange.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'Waiting for Approval',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Security will review this request shortly.',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ] else if (isExpired || status == 'expired') ...[
                          // 已过期
                          Container(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(Icons.timer_off, size: 64, color: Colors.red.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'Pass Expired',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'This visitor pass is no longer valid.',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ] else if (status == 'checked-out') ...[
                          // 已离场
                          Container(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(Icons.check_circle, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'Visit Completed',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Visitor has checked out.',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ] else if (status == 'denied') ...[
                          // 已拒绝
                          Container(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(Icons.cancel, size: 64, color: Colors.red.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'Request Denied',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'This visitor request was denied by security.',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        // 状态显示
                        if (status == 'checked-in') ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.login, size: 16, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Currently inside premises',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 分享按钮
                if (isValid && qrCode != null)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.share),
                      label: Text(
                        'Share with Visitor',
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                      ),
                      onPressed: () async {
                        final expiryStr = qrExpiresAt != null 
                            ? DateFormat('dd MMM yyyy, HH:mm').format(qrExpiresAt)
                            : 'N/A';
                        final message = '''
🎫 Visitor Pass - Vanguard

Visitor: $visitorName
Type: ${entryType == 'walk-in' ? 'Walk-in' : 'By Car'}
${vehiclePlate != null && vehiclePlate.isNotEmpty ? 'Plate: $vehiclePlate\n' : ''}Valid until: $expiryStr

Please show this pass to security at the entrance.
''';
                        try {
                          await Share.share(message, subject: 'Visitor Pass for $visitorName');
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Could not share: $e', style: GoogleFonts.montserrat()),
                                backgroundColor: Colors.red.shade400,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // 规则提示
                if (entryType == 'car' && isValid)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Parking Rules',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Maximum parking duration: 4 hours\n'
                          '• Must leave by 2:00 AM\n'
                          '• Overtime will result in security notification',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            color: Colors.orange.shade700,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
