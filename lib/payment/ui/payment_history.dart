// lib/payment/ui/payment_history.dart
// 支付历史页面

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/transaction_model.dart';
import '../controllers/payment_controller.dart';

class PaymentHistoryPage extends StatefulWidget {
  const PaymentHistoryPage({Key? key}) : super(key: key);

  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  final PaymentController _controller = PaymentController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _viewTransactionDetails(Transaction transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          '交易详情',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('交易ID', transaction.id ?? 'N/A'),
              _buildDetailRow('金额', 'RM ${transaction.amount.toStringAsFixed(2)}'),
              _buildDetailRow('费用类型', transaction.feeTypeDisplayName),
              _buildDetailRow('支付方式', transaction.paymentMethodDisplayName),
              _buildDetailRow('状态', transaction.statusDisplayName),
              _buildDetailRow(
                '创建时间',
                DateFormat('yyyy-MM-dd HH:mm:ss').format(transaction.createdAt),
              ),
              if (transaction.completedAt != null)
                _buildDetailRow(
                  '完成时间',
                  DateFormat('yyyy-MM-dd HH:mm:ss').format(transaction.completedAt!),
                ),
              if (transaction.transactionHash != null) ...[
                const Divider(),
                _buildDetailRow('交易哈希', transaction.transactionHash!),
                if (transaction.fromAddress != null)
                  _buildDetailRow('发送地址', transaction.fromAddress!),
                if (transaction.toAddress != null)
                  _buildDetailRow('接收地址', transaction.toAddress!),
                if (transaction.blockNumber != null)
                  _buildDetailRow('区块号', transaction.blockNumber.toString()),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _viewOnBlockchain(transaction.transactionHash!),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('在区块链浏览器查看'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                  ),
                ),
              ],
              if (transaction.receiptId != null) ...[
                const Divider(),
                _buildDetailRow('收据ID', transaction.receiptId!),
              ],
              if (transaction.description != null)
                _buildDetailRow('说明', transaction.description!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '关闭',
              style: GoogleFonts.montserrat(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.montserrat(
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _viewOnBlockchain(String transactionHash) async {
    // Ganache本地网络没有公共浏览器，但可以显示交易哈希
    // 在实际应用中，可以链接到Etherscan等区块链浏览器
    final url = 'https://etherscan.io/tx/$transactionHash'; // 示例链接
    
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('无法打开链接。交易哈希: $transactionHash'),
          ),
        );
      }
    }
  }

  Color _getStatusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.completed:
        return Colors.green;
      case TransactionStatus.pending:
      case TransactionStatus.processing:
        return Colors.orange;
      case TransactionStatus.failed:
      case TransactionStatus.cancelled:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.completed:
        return Icons.check_circle;
      case TransactionStatus.pending:
        return Icons.pending;
      case TransactionStatus.processing:
        return Icons.sync;
      case TransactionStatus.failed:
        return Icons.error;
      case TransactionStatus.cancelled:
        return Icons.cancel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('支付历史'),
        ),
        body: const Center(
          child: Text('请先登录'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '支付历史',
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
      body: StreamBuilder(
        stream: _controller.getTransactionHistory(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '加载失败: ${snapshot.error}',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          final transactions = (snapshot.data as List<Transaction>?) ?? [];

          if (transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无交易记录',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '您的支付历史将显示在这里',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () => _viewTransactionDetails(transaction),
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
                                    transaction.feeTypeDisplayName,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    transaction.paymentMethodDisplayName,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'RM ${transaction.amount.toStringAsFixed(2)}',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(transaction.status)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _getStatusIcon(transaction.status),
                                        size: 14,
                                        color: _getStatusColor(transaction.status),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        transaction.statusDisplayName,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          color: _getStatusColor(transaction.status),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('yyyy-MM-dd HH:mm').format(
                                transaction.createdAt,
                              ),
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (transaction.transactionHash != null) ...[
                              const SizedBox(width: 16),
                              Icon(
                                Icons.link,
                                size: 14,
                                color: Colors.orange[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${transaction.transactionHash!.substring(0, 10)}...',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    color: Colors.orange[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
