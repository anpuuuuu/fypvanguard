// lib/admin/payment_history_admin.dart
// Admin payment history page - View all user transactions

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../payment/models/transaction_model.dart';
import '../payment/controllers/payment_controller.dart';

class AdminPaymentHistoryPage extends StatefulWidget {
  const AdminPaymentHistoryPage({Key? key}) : super(key: key);

  @override
  State<AdminPaymentHistoryPage> createState() => _AdminPaymentHistoryPageState();
}

class _AdminPaymentHistoryPageState extends State<AdminPaymentHistoryPage> {
  final PaymentController _controller = PaymentController();
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'Completed', 'Pending', 'Processing', 'Failed'];

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

  Stream<List<Transaction>> _getFilteredTransactions() {
    if (_selectedFilter == 'All') {
      return _controller.getAllTransactions();
    } else {
      final status = _getStatusFromFilter(_selectedFilter);
      return _controller.getTransactionsByStatus(status);
    }
  }

  TransactionStatus _getStatusFromFilter(String filter) {
    switch (filter) {
      case 'Completed':
        return TransactionStatus.completed;
      case 'Pending':
        return TransactionStatus.pending;
      case 'Processing':
        return TransactionStatus.processing;
      case 'Failed':
        return TransactionStatus.failed;
      default:
        return TransactionStatus.completed;
    }
  }

  Future<Map<String, String>> _getUserInfo(String userId) async {
    try {
      final accountDoc = await FirebaseFirestore.instance
          .collection('accounts')
          .doc(userId)
          .get();
      
      final accountData = accountDoc.data();
      final residentId = accountData?['residentId'] as String? ?? userId;
      
      final residentDoc = await FirebaseFirestore.instance
          .collection('residents')
          .doc(residentId)
          .get();
      
      final residentData = residentDoc.data();
      return {
        'name': residentData?['fullName'] as String? ?? 'Unknown User',
        'email': accountData?['email'] as String? ?? 'No email',
        'residentId': residentId,
      };
    } catch (e) {
      return {
        'name': 'Unknown User',
        'email': 'No email',
        'residentId': userId,
      };
    }
  }

  void _viewTransactionDetails(Transaction transaction) async {
    final userInfo = await _getUserInfo(transaction.userId);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          'Transaction Details',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Transaction ID', transaction.id ?? 'N/A'),
              _buildDetailRow('User Name', userInfo['name']!),
              _buildDetailRow('User Email', userInfo['email']!),
              _buildDetailRow('Resident ID', userInfo['residentId']!),
              const Divider(),
              _buildDetailRow('Amount', 'RM ${transaction.amount.toStringAsFixed(2)}'),
              _buildDetailRow('Fee Type', transaction.feeTypeDisplayName),
              _buildDetailRow('Payment Method', transaction.paymentMethodDisplayName),
              _buildDetailRow('Status', transaction.statusDisplayName),
              _buildDetailRow(
                'Created At',
                DateFormat('yyyy-MM-dd HH:mm:ss').format(transaction.createdAt),
              ),
              if (transaction.completedAt != null)
                _buildDetailRow(
                  'Completed At',
                  DateFormat('yyyy-MM-dd HH:mm:ss').format(transaction.completedAt!),
                ),
              if (transaction.transactionHash != null) ...[
                const Divider(),
                _buildDetailRow('Transaction Hash', transaction.transactionHash!),
                if (transaction.fromAddress != null)
                  _buildDetailRow('From Address', transaction.fromAddress!),
                if (transaction.toAddress != null)
                  _buildDetailRow('To Address', transaction.toAddress!),
                if (transaction.blockNumber != null)
                  _buildDetailRow('Block Number', transaction.blockNumber.toString()),
              ],
              if (transaction.receiptId != null) ...[
                const Divider(),
                _buildDetailRow('Receipt ID', transaction.receiptId!),
              ],
              if (transaction.description != null)
                _buildDetailRow('Description', transaction.description!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
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
            width: 120,
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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        elevation: 0,
        title: Text(
          'Payment History',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: Column(
        children: [
          // Filter section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Text(
                  'Filter:',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedFilter,
                    isExpanded: true,
                    items: _filterOptions.map((option) {
                      return DropdownMenuItem(
                        value: option,
                        child: Text(
                          option,
                          style: GoogleFonts.montserrat(),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedFilter = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          // Transactions list
          Expanded(
            child: StreamBuilder<List<Transaction>>(
              stream: _getFilteredTransactions(),
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
                          'Failed to load: ${snapshot.error}',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            // Try to create index if needed
                            final error = snapshot.error.toString();
                            if (error.contains('index')) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Please create the Firestore index. Check the error message for the link.',
                                  ),
                                  duration: const Duration(seconds: 5),
                                ),
                              );
                            }
                          },
                          child: Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final transactions = snapshot.data ?? [];

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
                          'No Transactions Found',
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No payment records match the selected filter',
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
                    return FutureBuilder<Map<String, String>>(
                      future: _getUserInfo(transaction.userId),
                      builder: (context, userSnapshot) {
                        final userName = userSnapshot.data?['name'] ?? 'Loading...';
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
                                              userName,
                                              style: GoogleFonts.montserrat(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
