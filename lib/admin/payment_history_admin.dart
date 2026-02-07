// lib/admin/payment_history_admin.dart
// Admin payment history page - Resident-centric view with payment status

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../payment/models/transaction_model.dart';
import '../payment/controllers/payment_controller.dart';
import '../payment/services/payment_type_service.dart';

class AdminPaymentHistoryPage extends StatefulWidget {
  const AdminPaymentHistoryPage({Key? key}) : super(key: key);

  @override
  State<AdminPaymentHistoryPage> createState() => _AdminPaymentHistoryPageState();
}

class _ResidentPaymentStatus {
  final String residentId;
  final String unitNumber;
  final String residentName;
  final String role;
  final List<_FeeStatus> fees;

  _ResidentPaymentStatus({
    required this.residentId,
    required this.unitNumber,
    required this.residentName,
    required this.role,
    required this.fees,
  });

  int get paidCount => fees.where((f) => f.status == 'paid').length;
  int get pendingCount => fees.where((f) => f.status == 'pending').length;
}

class _FeeStatus {
  final String feeTypeKey;
  final String feeTypeName;
  final double amount;
  final String status; // 'paid' | 'pending'
  final DateTime? dueDate;
  final String? description;

  _FeeStatus({
    required this.feeTypeKey,
    required this.feeTypeName,
    required this.amount,
    required this.status,
    this.dueDate,
    this.description,
  });
}

class _AdminPaymentHistoryPageState extends State<AdminPaymentHistoryPage>
    with SingleTickerProviderStateMixin {
  final PaymentController _controller = PaymentController();
  final PaymentTypeService _paymentTypeService = PaymentTypeService();

  late TabController _tabController;
  List<_ResidentPaymentStatus> _residents = [];
  bool _loadingResidents = true;
  String _searchQuery = '';
  String _selectedFilter = 'All'; // All, Paid, Unpaid
  final List<String> _filterOptions = ['All', 'Has Unpaid', 'All Paid'];

  // Transaction tab
  String _selectedTxFilter = 'All';
  final List<String> _txFilterOptions = ['All', 'Completed', 'Pending', 'Processing', 'Failed'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _controller.initialize();
    _loadResidentsWithPaymentStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadResidentsWithPaymentStatus() async {
    setState(() => _loadingResidents = true);
    try {
      // Load all approved residents (owners and tenants)
      final accountsSnapshot = await FirebaseFirestore.instance
          .collection('accounts')
          .where('status', isEqualTo: 'approved')
          .where('role', whereIn: ['owner', 'tenant'])
          .get();

      final residentIds = <String>{};
      final residentList = <Map<String, dynamic>>[];

      for (var accountDoc in accountsSnapshot.docs) {
        final accountData = accountDoc.data();
        final residentId = accountData['residentId'] as String? ?? accountDoc.id;

        if (residentIds.contains(residentId)) continue;
        residentIds.add(residentId);

        final residentDoc = await FirebaseFirestore.instance
            .collection('residents')
            .doc(residentId)
            .get();

        if (residentDoc.exists) {
          final residentData = residentDoc.data()!;
          residentList.add({
            'id': residentId,
            'unitNumber': residentData['unitNumber'] as String? ?? 'N/A',
            'fullName': residentData['fullName'] as String? ?? 'Unknown',
            'role': accountData['role'] as String? ?? 'owner',
          });
        }
      }

      // Load all pendingFees (both pending and paid)
      final pendingFeesSnapshot = await FirebaseFirestore.instance
          .collection('pendingFees')
          .get();

      final feeTypeNames = <String, String>{};
      for (var doc in pendingFeesSnapshot.docs) {
        final feeTypeKey = doc.data()['feeType'] as String? ?? 'other';
        if (!feeTypeNames.containsKey(feeTypeKey)) {
          feeTypeNames[feeTypeKey] = await _paymentTypeService.getDisplayName(feeTypeKey);
        }
      }

      // Map residentId -> list of fees
      final residentFeesMap = <String, List<_FeeStatus>>{};
      for (var doc in pendingFeesSnapshot.docs) {
        final data = doc.data();
        final residentId = data['residentId'] as String?;
        if (residentId == null) continue;

        final feeTypeKey = data['feeType'] as String? ?? 'other';
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final status = data['status'] as String? ?? 'pending';
        final dueDate = data['dueDate'] != null
            ? (data['dueDate'] as Timestamp).toDate()
            : null;
        final description = data['description'] as String?;

        residentFeesMap.putIfAbsent(residentId, () => []).add(_FeeStatus(
          feeTypeKey: feeTypeKey,
          feeTypeName: feeTypeNames[feeTypeKey] ?? feeTypeKey,
          amount: amount,
          status: status,
          dueDate: dueDate,
          description: description,
        ));
      }

      final result = <_ResidentPaymentStatus>[];
      for (var r in residentList) {
        final fees = residentFeesMap[r['id'] as String] ?? [];
        result.add(_ResidentPaymentStatus(
          residentId: r['id'] as String,
          unitNumber: r['unitNumber'] as String,
          residentName: r['fullName'] as String,
          role: r['role'] as String,
          fees: fees..sort((a, b) => (a.dueDate ?? DateTime(0)).compareTo(b.dueDate ?? DateTime(0))),
        ));
      }

      result.sort((a, b) {
        final unitCompare = a.unitNumber.compareTo(b.unitNumber);
        if (unitCompare != 0) return unitCompare;
        return a.residentName.compareTo(b.residentName);
      });

      setState(() {
        _residents = result;
        _loadingResidents = false;
      });
    } catch (e) {
      setState(() => _loadingResidents = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load: $e')),
        );
      }
    }
  }

  List<_ResidentPaymentStatus> get _filteredResidents {
    var list = _residents;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((r) {
        return r.unitNumber.toLowerCase().contains(q) ||
            r.residentName.toLowerCase().contains(q);
      }).toList();
    }
    if (_selectedFilter == 'Has Unpaid') {
      list = list.where((r) => r.pendingCount > 0).toList();
    } else if (_selectedFilter == 'All Paid') {
      list = list.where((r) => r.fees.isNotEmpty && r.pendingCount == 0).toList();
    }
    return list;
  }

  Stream<List<Transaction>> _getFilteredTransactions() {
    if (_selectedTxFilter == 'All') {
      return _controller.getAllTransactions();
    } else {
      final status = _getStatusFromFilter(_selectedTxFilter);
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
        'unitNumber': residentData?['unitNumber'] as String? ?? 'N/A',
      };
    } catch (e) {
      return {
        'name': 'Unknown User',
        'email': 'No email',
        'residentId': userId,
        'unitNumber': 'N/A',
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people, size: 18),
                  SizedBox(width: 6),
                  Text('By Resident', style: GoogleFonts.montserrat()),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long, size: 18),
                  SizedBox(width: 6),
                  Text('Transactions', style: GoogleFonts.montserrat()),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildResidentListTab(),
          _buildTransactionsTab(),
        ],
      ),
    );
  }

  Widget _buildResidentListTab() {
    return Column(
      children: [
        // Search and filter
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search by unit or name...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Filter:', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _selectedFilter,
                      isExpanded: true,
                      items: _filterOptions.map((o) => DropdownMenuItem(value: o, child: Text(o, style: GoogleFonts.montserrat()))).toList(),
                      onChanged: (v) => setState(() => _selectedFilter = v ?? 'All'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingResidents
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadResidentsWithPaymentStatus,
                  child: _buildResidentList(),
                ),
        ),
      ],
    );
  }

  Widget _buildResidentList() {
    final list = _filteredResidents;

    if (list.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: 80),
          Center(
            child: Column(
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('No residents found', style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (_, index) {
        final r = list[index];
        return _buildResidentCard(r);
      },
    );
  }

  Widget _buildResidentCard(_ResidentPaymentStatus r) {
    final hasUnpaid = r.pendingCount > 0;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: hasUnpaid ? Colors.orange.shade100 : Colors.green.shade100,
          child: Icon(
            hasUnpaid ? Icons.pending_actions : Icons.check_circle,
            color: hasUnpaid ? Colors.orange.shade700 : Colors.green.shade700,
          ),
        ),
        title: Text(
          'Unit ${r.unitNumber}',
          style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${r.residentName} • ${r.role}',
          style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (r.fees.isEmpty)
              Text('No fees', style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey))
            else ...[
              if (r.paidCount > 0)
                Text('${r.paidCount} paid', style: GoogleFonts.montserrat(fontSize: 12, color: Colors.green.shade700)),
              if (r.pendingCount > 0)
                Text('${r.pendingCount} unpaid', style: GoogleFonts.montserrat(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
        children: [
          if (r.fees.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No payment records', style: GoogleFonts.montserrat(color: Colors.grey)),
            )
          else
            ...r.fees.map((f) => _buildFeeRow(f)),
        ],
      ),
    );
  }

  Widget _buildFeeRow(_FeeStatus f) {
    final isPaid = f.status == 'paid';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(isPaid ? Icons.check_circle : Icons.schedule, color: isPaid ? Colors.green : Colors.orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.feeTypeName, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                if (f.dueDate != null)
                  Text('Due: ${DateFormat('yyyy-MM-dd').format(f.dueDate!)}', style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          Text('RM ${f.amount.toStringAsFixed(2)}', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isPaid ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(isPaid ? 'Paid' : 'Unpaid', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: isPaid ? Colors.green.shade700 : Colors.orange.shade700)),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Text('Filter:', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedTxFilter,
                  isExpanded: true,
                  items: _txFilterOptions.map((o) => DropdownMenuItem(value: o, child: Text(o, style: GoogleFonts.montserrat()))).toList(),
                  onChanged: (v) => setState(() => _selectedTxFilter = v ?? 'All'),
                ),
              ),
            ],
          ),
        ),
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
                                              'Unit ${userSnapshot.data?["unitNumber"] ?? "N/A"} • $userName',
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
      );
  }
}
