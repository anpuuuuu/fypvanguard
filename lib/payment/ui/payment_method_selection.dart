// lib/payment/ui/payment_method_selection.dart
// 支付方法选择页面

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../controllers/payment_controller.dart';
import '../services/blockchain_service.dart';
import 'dart:io' show Platform;

class PaymentMethodSelectionPage extends StatefulWidget {
  final double amount;
  final FeeType feeType;
  final String description;

  const PaymentMethodSelectionPage({
    Key? key,
    required this.amount,
    required this.feeType,
    required this.description,
  }) : super(key: key);

  @override
  State<PaymentMethodSelectionPage> createState() =>
      _PaymentMethodSelectionPageState();
}

class _PaymentMethodSelectionPageState
    extends State<PaymentMethodSelectionPage> {
  final PaymentController _controller = PaymentController();
  PaymentMethod? _selectedMethod;
  bool _isProcessing = false;

  // 区块链支付相关
  final TextEditingController _fromAddressController = TextEditingController();
  final TextEditingController _privateKeyController = TextEditingController();
  final TextEditingController _toAddressController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller.initialize();
    // 设置默认接收地址（应该从配置或Firestore获取）
    _toAddressController.text = '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb'; // 示例地址
  }

  @override
  void dispose() {
    _fromAddressController.dispose();
    _privateKeyController.dispose();
    _toAddressController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (_selectedMethod == null) {
      _showError('请选择支付方式');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      Transaction transaction;

      if (_selectedMethod == PaymentMethod.blockchain) {
        // 验证表单
        if (!_formKey.currentState!.validate()) {
          setState(() => _isProcessing = false);
          return;
        }

        // 处理区块链支付
        transaction = await _controller.processBlockchainPayment(
          amount: widget.amount,
          feeType: widget.feeType,
          fromAddress: _fromAddressController.text.trim(),
          privateKey: _privateKeyController.text.trim(),
          toAddress: _toAddressController.text.trim(),
          description: widget.description,
        );
      } else {
        // 处理Stripe支付
        // 注意：实际应用中应该使用Stripe的支付表单收集卡信息
        // 这里仅作为示例
        _showError('Stripe支付功能需要配置Stripe密钥和支付表单');
        setState(() => _isProcessing = false);
        return;

        // 示例代码（需要实际实现）：
        // transaction = await _controller.processStripePayment(
        //   amount: widget.amount,
        //   feeType: widget.feeType,
        //   paymentMethodId: 'pm_xxx', // 从Stripe支付表单获取
        //   description: widget.description,
        // );
      }

      // 支付成功
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('支付成功！交易ID: ${transaction.id}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('支付失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '选择支付方式',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 支付摘要卡片
            _buildSummaryCard(),

            const SizedBox(height: 24),

            // 支付方式选择
            Text(
              '选择支付方式',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 16),

            // 区块链支付选项
            _buildPaymentMethodCard(
              icon: Icons.account_balance_wallet,
              title: '区块链支付',
              subtitle: '使用以太坊网络（Ganache测试环境）',
              method: PaymentMethod.blockchain,
              color: Colors.orange,
            ),

            const SizedBox(height: 12),

            // Stripe支付选项
            _buildPaymentMethodCard(
              icon: Icons.credit_card,
              title: '信用卡/借记卡',
              subtitle: '使用Stripe安全支付',
              method: PaymentMethod.stripe,
              color: Colors.blue,
            ),

            const SizedBox(height: 24),

            // 区块链支付表单（仅在选择区块链时显示）
            if (_selectedMethod == PaymentMethod.blockchain)
              _buildBlockchainForm(),

            // Stripe支付说明（仅在选择Stripe时显示）
            if (_selectedMethod == PaymentMethod.stripe)
              _buildStripeInfo(),

            const SizedBox(height: 24),

            // 支付按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        '确认支付 RM ${widget.amount.toStringAsFixed(2)}',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '支付摘要',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '费用类型',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  _getFeeTypeName(widget.feeType),
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '金额',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'RM ${widget.amount.toStringAsFixed(2)}',
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            if (widget.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                '说明',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.description,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required PaymentMethod method,
    required Color color,
  }) {
    final isSelected = _selectedMethod == method;

    return Card(
      elevation: isSelected ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? color : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() => _selectedMethod = method);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Radio<PaymentMethod>(
                value: method,
                groupValue: _selectedMethod,
                onChanged: (value) {
                  setState(() => _selectedMethod = value);
                },
                activeColor: color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlockchainForm() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '区块链支付信息',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fromAddressController,
                decoration: InputDecoration(
                  labelText: '发送地址（从Ganache获取）',
                  hintText: '0x...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.account_balance_wallet),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入发送地址';
                  }
                  if (!BlockchainService.isValidAddress(value)) {
                    return '无效的以太坊地址';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _privateKeyController,
                decoration: InputDecoration(
                  labelText: '私钥（十六进制，不带0x前缀）',
                  hintText: '输入您的以太坊私钥',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.vpn_key),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入私钥';
                  }
                  if (value.length != 64) {
                    return '私钥必须是64个十六进制字符';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _toAddressController,
                decoration: InputDecoration(
                  labelText: '接收地址',
                  hintText: '0x...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.account_balance_wallet),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入接收地址';
                  }
                  if (!BlockchainService.isValidAddress(value)) {
                    return '无效的以太坊地址';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '注意：这是测试环境。请从Ganache界面复制账户地址和私钥。'
                        '私钥用于签名交易，地址用于标识发送方。',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStripeInfo() {
    return Card(
      elevation: 2,
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
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Stripe支付',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Stripe支付功能需要配置Stripe API密钥和实现支付表单。'
              '在实际应用中，应该使用Stripe的支付表单来收集用户的卡信息。',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: Colors.blue.shade900,
              ),
            ),
          ],
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
