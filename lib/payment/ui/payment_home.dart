// lib/payment/ui/payment_home.dart
// 支付主页 - 显示待支付费用和支付入口

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../controllers/payment_controller.dart';
import '../models/transaction_model.dart';
import 'payment_method_selection.dart';
import 'payment_history.dart';

class PaymentHomePage extends StatefulWidget {
  const PaymentHomePage({Key? key}) : super(key: key);

  @override
  State<PaymentHomePage> createState() => _PaymentHomePageState();
}

class _PaymentHomePageState extends State<PaymentHomePage> {
  final PaymentController _controller = PaymentController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _residentId;
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingFees = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _controller.initialize();
    await _loadResidentInfo();
    await _loadPendingFees();
  }

  Future<void> _loadResidentInfo() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final accountDoc = await FirebaseFirestore.instance
        .collection('accounts')
        .doc(user.uid)
        .get();
    final accountData = accountDoc.data();
    setState(() {
      _residentId = accountData?['residentId'] as String? ?? user.uid;
    });
  }

  Future<void> _loadPendingFees() async {
    if (_residentId == null) return;

    setState(() => _isLoading = true);
    try {
      final fees = await _controller.getPendingFees(_residentId!);
      setState(() {
        _pendingFees = fees;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载费用失败: $e')),
        );
      }
    }
  }

  void _navigateToPaymentMethod(Map<String, dynamic> fee) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentMethodSelectionPage(
          amount: fee['amount'] as double,
          feeType: fee['type'] as FeeType,
          description: fee['description'] as String? ?? '',
        ),
      ),
    ).then((_) => _loadPendingFees()); // 支付完成后刷新
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '支付中心',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PaymentHistoryPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPendingFees,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 待支付费用卡片
                    if (_pendingFees.isEmpty)
                      _buildEmptyState()
                    else
                      ..._pendingFees.map((fee) => _buildFeeCard(fee)),

                    const SizedBox(height: 24),

                    // 支付历史快捷入口
                    _buildHistorySection(),

                    const SizedBox(height: 24),

                    // 支付说明
                    _buildInfoCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无待支付费用',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '您当前没有需要支付的费用',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeCard(Map<String, dynamic> fee) {
    final feeType = fee['type'] as FeeType;
    final amount = fee['amount'] as double;
    final description = fee['description'] as String? ?? '';
    final dueDate = fee['dueDate'] as DateTime?;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToPaymentMethod(fee),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getFeeTypeName(feeType),
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'RM ${amount.toStringAsFixed(2)}',
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              if (dueDate != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '到期日: ${DateFormat('yyyy-MM-dd').format(dueDate)}',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _navigateToPaymentMethod(fee),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    '立即支付',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PaymentHistoryPage(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.history,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '支付历史',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '查看所有交易记录',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 1,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  '支付说明',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoItem('• 支持区块链支付和传统支付方式'),
            _buildInfoItem('• 区块链支付使用以太坊网络（Ganache测试环境）'),
            _buildInfoItem('• 传统支付支持信用卡/借记卡（Stripe）'),
            _buildInfoItem('• 所有交易记录将安全存储在系统中'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.montserrat(
          fontSize: 13,
          color: Colors.blue.shade900,
        ),
      ),
    );
  }

  String _getFeeTypeName(FeeType feeType) {
    switch (feeType) {
      case FeeType.managementFee:
        return '管理费';
      case FeeType.maintenanceFee:
        return '维护费';
      case FeeType.lateFee:
        return '滞纳金';
      case FeeType.other:
        return '其他费用';
    }
  }
}
