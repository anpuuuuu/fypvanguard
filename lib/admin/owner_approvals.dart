// lib/admin/owner_approvals.dart
// 业主审批页面 - 支持 OCR 文档验证功能

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/ocr_verification_service.dart';

class OwnerApprovalsPage extends StatefulWidget {
  const OwnerApprovalsPage({super.key});

  @override
  _OwnerApprovalsPageState createState() => _OwnerApprovalsPageState();
}

class _OwnerApprovalsPageState extends State<OwnerApprovalsPage> {
  // OCR 验证服务实例
  final OcrVerificationService _ocrService = OcrVerificationService();

  // 正在验证的文档 ID 集合（用于显示加载状态）
  final Set<String> _verifyingIds = {};

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _approve(String id) =>
      FirebaseFirestore.instance.collection('accounts').doc(id).update({'status': 'approved'});

  Future<void> _reject(String id) =>
      FirebaseFirestore.instance.collection('accounts').doc(id).update({'status': 'rejected'});

  Future<Map<String, dynamic>?> _fetchResident(String resId) async {
    final doc = await FirebaseFirestore.instance.collection('residents').doc(resId).get();
    return doc.exists ? doc.data() : null;
  }

  /// 执行 OCR 验证
  Future<void> _verifyDocument(String residentId, Map<String, dynamic> residentData) async {
    // 设置加载状态
    setState(() => _verifyingIds.add(residentId));

    try {
      final base64Image = residentData['proofDocBase64'] as String?;
      final fullName = residentData['fullName'] as String? ?? '';
      final unitNumber = residentData['unitNumber'] as String? ?? '';

      if (base64Image == null || base64Image.isEmpty) {
        _showSnack('没有找到文档图片');
        return;
      }

      // 调用 OCR 验证服务
      final result = await _ocrService.verifyDocument(
        base64Image: base64Image,
        ownerName: fullName,
        unitNumber: unitNumber,
      );

      // 保存验证结果到 Firestore
      await FirebaseFirestore.instance.collection('residents').doc(residentId).update({
        'ocrVerification': {
          ...result.toMap(),
          'scannedAt': FieldValue.serverTimestamp(),
        },
      });

      _showSnack('文档验证完成！可信度: ${result.confidenceScore}%');
    } catch (e) {
      _showSnack('验证失败: $e');
    } finally {
      setState(() => _verifyingIds.remove(residentId));
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// 获取可信度对应的颜色
  Color _getConfidenceColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  /// 获取可信度对应的图标
  IconData _getConfidenceIcon(int score) {
    if (score >= 80) return Icons.check_circle;
    if (score >= 60) return Icons.warning;
    return Icons.error;
  }

  /// 获取推荐操作的显示文本
  String _getRecommendationText(String recommendation) {
    switch (recommendation) {
      case 'auto_approve':
        return 'Recommended: Auto Approve';
      case 'manual_review':
        return 'Recommended: Manual Review';
      case 'needs_attention':
        return 'Recommended: Careful Review';
      default:
        return 'Unknown';
    }
  }

  /// 构建 OCR 验证结果卡片
  Widget _buildOcrResultCard(Map<String, dynamic> ocrData) {
    final result = OcrVerificationResult.fromMap(ocrData);
    final color = _getConfidenceColor(result.confidenceScore);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行：可信度分数
          Row(
            children: [
              Icon(_getConfidenceIcon(result.confidenceScore), color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                'Confidence: ${result.confidenceScore}/100',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 推荐操作
          Text(
            _getRecommendationText(result.recommendation),
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const Divider(height: 16),

          // 验证详情
          _buildVerificationItem(
            'Name Match',
            result.nameMatched,
            '${result.nameMatchScore}%',
          ),
          const SizedBox(height: 4),
          _buildVerificationItem(
            'Unit Match',
            result.unitMatched,
            '${result.unitMatchScore}%',
          ),
          const SizedBox(height: 4),
          _buildVerificationItem(
            'Document Type',
            result.documentTypeDetected,
            result.documentTypeDetected ? 'Detected' : 'Not Found',
          ),

          // 检测到的关键词
          if (result.detectedKeywords.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: result.detectedKeywords.take(5).map((keyword) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(26),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    keyword,
                    style: GoogleFonts.montserrat(fontSize: 10, color: Colors.blue[700]),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建单个验证项
  Widget _buildVerificationItem(String label, bool matched, String detail) {
    return Row(
      children: [
        Icon(
          matched ? Icons.check_circle_outline : Icons.cancel_outlined,
          size: 16,
          color: matched ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: GoogleFonts.montserrat(fontSize: 12),
        ),
        Text(
          detail,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: matched ? Colors.green[700] : Colors.red[700],
          ),
        ),
      ],
    );
  }

  /// 显示文档详情对话框（包含 OCR 提取的文字）
  void _showDocumentDialog(BuildContext context, Uint8List imageBytes, Map<String, dynamic>? ocrData) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
                child: Row(
                  children: [
                    Text(
                      'Document Preview',
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // 图片预览
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      ClipRRect(
                        child: Image.memory(imageBytes, fit: BoxFit.contain),
                      ),

                      // OCR 提取的文字（如果有）
                      if (ocrData != null && ocrData['extractedText'] != null) ...[
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Extracted Text:',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  ocrData['extractedText'] as String,
                                  style: GoogleFonts.montserrat(fontSize: 12),
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
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        elevation: 0,
        centerTitle: true,
        title: Text('Owner Approvals',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/admin'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('accounts')
              .where('role', isEqualTo: 'owner')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (ctx, snap) {
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}', style: GoogleFonts.montserrat()));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text('No pending owner approvals.',
                        style: GoogleFonts.montserrat(color: Colors.grey)),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              itemCount: docs.length,
              itemBuilder: (context, i) {
                final acc = docs[i];
                final data = acc.data()! as Map<String, dynamic>;
                final resId = data['residentId'] as String?;
                final isVerifying = _verifyingIds.contains(resId);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: resId == null
                        ? Text('Invalid resident data', style: GoogleFonts.montserrat())
                        : FutureBuilder<Map<String, dynamic>?>(
                      future: _fetchResident(resId),
                      builder: (ctx2, fb) {
                        if (fb.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final resident = fb.data;
                        if (resident == null) {
                          return Text('Resident data not found', style: GoogleFonts.montserrat());
                        }

                        final name = resident['fullName'] ?? '—';
                        final unit = resident['unitNumber'] ?? '—';
                        final base64Img = resident['proofDocBase64'] as String?;
                        final ocrData = resident['ocrVerification'] as Map<String, dynamic>?;
                        final hasOcrResult = ocrData != null && ocrData['confidenceScore'] != null;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 用户信息行
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['username'] ?? '—',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$name • Unit $unit',
                                        style: GoogleFonts.montserrat(color: Colors.grey[700]),
                                      ),
                                    ],
                                  ),
                                ),

                                // 文档预览缩略图
                                if (base64Img != null && base64Img.isNotEmpty) ...[
                                  GestureDetector(
                                    onTap: () {
                                      final bytes = base64Decode(base64Img);
                                      _showDocumentDialog(context, bytes, ocrData);
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        base64Decode(base64Img),
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  Icon(Icons.insert_drive_file, size: 48, color: Colors.grey[400]),
                                ],
                              ],
                            ),

                            // OCR 验证结果（如果已验证）
                            if (hasOcrResult) _buildOcrResultCard(ocrData!),

                            // 未验证提示
                            if (!hasOcrResult && !isVerifying)
                              Container(
                                margin: const EdgeInsets.only(top: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Document not verified yet',
                                      style: GoogleFonts.montserrat(
                                        color: Colors.grey[600],
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // 验证中加载状态
                            if (isVerifying)
                              Container(
                                margin: const EdgeInsets.only(top: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withAlpha(26),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Scanning document...',
                                      style: GoogleFonts.montserrat(color: Colors.blue[700]),
                                    ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 16),

                            // 操作按钮行
                            Row(
                              children: [
                                // 验证文档按钮
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.blue,
                                      side: const BorderSide(color: Colors.blue),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                    icon: const Icon(Icons.document_scanner, size: 18),
                                    label: Text(
                                      hasOcrResult ? 'Re-scan' : 'Verify',
                                      style: GoogleFonts.montserrat(),
                                    ),
                                    onPressed: isVerifying
                                        ? null
                                        : () => _verifyDocument(resId, resident),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // 通过按钮
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                    onPressed: isVerifying ? null : () => _approve(acc.id),
                                    child: Text('Approve',
                                        style: GoogleFonts.montserrat(color: Colors.white)),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // 拒绝按钮
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                    onPressed: isVerifying ? null : () => _reject(acc.id),
                                    child: Text('Reject',
                                        style: GoogleFonts.montserrat(color: Colors.white)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        selectedItemColor: Colors.red.shade700,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.montserrat(fontSize: 12),
        unselectedLabelStyle: GoogleFonts.montserrat(fontSize: 12),
        onTap: (i) {
          switch (i) {
            case 0:
              GoRouter.of(context).go('/admin');
              break;
            case 1:
              GoRouter.of(context).go('/admin/ownerApprovals');
              break;
            case 2:
              GoRouter.of(context).go('/admin/userManagement');
              break;
            case 3:
              GoRouter.of(context).go('/admin/announcements');
              break;
            case 4:
              GoRouter.of(context).go('/admin/facilities');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person_add), label: 'Approvals'),
          BottomNavigationBarItem(icon: Icon(Icons.manage_accounts), label: 'Users'),
          BottomNavigationBarItem(icon: Icon(Icons.campaign), label: 'Announcements'),
          BottomNavigationBarItem(icon: Icon(Icons.room_service), label: 'Facilities'),
        ],
      ),
    );
  }
}
