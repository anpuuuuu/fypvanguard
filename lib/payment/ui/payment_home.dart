// lib/payment/ui/payment_home.dart
// Payment home page - Display pending fees and payment entry

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../controllers/payment_controller.dart';
import '../models/transaction_model.dart';
import '../models/invoice_model.dart';
import 'payment_method_selection.dart';
import 'payment_history.dart';
import 'invoices_page.dart';

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
  List<Invoice> _recentInvoices = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _controller.initialize();
    await _loadResidentInfo();
    await _loadPendingFees();
    await _loadRecentInvoices();
  }

  Future<void> _loadRecentInvoices() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final list = await _controller.getRecentInvoices(user.uid, limit: 5);
      if (mounted) setState(() => _recentInvoices = list);
    } catch (_) {}
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
          SnackBar(content: Text('Failed to load fees: $e')),
        );
      }
    }
  }

  void _navigateToPaymentMethod(Map<String, dynamic> fee) {
    // First navigate to payment method selection
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentMethodSelectionPage(
          amount: fee['amount'] as double,
          feeType: fee['type'] as FeeType,
          feeTypeKey: fee['typeKey'] as String?,
          feeTypeName: fee['typeName'] as String? ?? _getFeeTypeName(fee['type'] as FeeType),
          description: fee['description'] as String? ?? '',
        ),
      ),
    ).then((result) {
      if (result == true) {
        _loadPendingFees();
        _loadRecentInvoices();
      }
    });
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
          'Payment Center',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            // Navigate back to user homepage
            context.go('/user');
          },
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
                    // Pending fees cards
                    if (_pendingFees.isEmpty)
                      _buildEmptyState()
                    else
                      ..._pendingFees.map((fee) => _buildFeeCard(fee)),

                    const SizedBox(height: 24),

                    // Recent invoices (after card/PayPal payment)
                    _buildRecentInvoicesSection(),

                    const SizedBox(height: 24),

                    // Payment history quick access
                    _buildHistorySection(),

                    const SizedBox(height: 24),

                    // Payment information
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
              'No Pending Fees',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You currently have no fees to pay',
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
    final feeTypeName = fee['typeName'] as String? ?? _getFeeTypeName(feeType);
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feeTypeName,
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'RM ${amount.toStringAsFixed(2)}',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.red.shade700,
                        ),
                        textAlign: TextAlign.right,
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
                      'Due Date: ${DateFormat('yyyy-MM-dd').format(dueDate)}',
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
                    'Pay Now',
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

  Widget _buildRecentInvoicesSection() {
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
              builder: (_) => const InvoicesPage(),
            ),
          ).then((_) => _loadRecentInvoices());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.receipt_long,
                      color: Colors.purple.shade700,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invoices',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _recentInvoices.isEmpty
                              ? 'View and download your payment invoices'
                              : '${_recentInvoices.length} recent invoice(s)',
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
              if (_recentInvoices.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                ..._recentInvoices.take(3).map((inv) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        inv.invoiceNumber,
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'RM ${inv.amount.toStringAsFixed(2)}',
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 4),
                Text(
                  'View all invoices →',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
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
                      'Payment History',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'View all transaction records',
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
                Expanded(
                  child: Text(
                    'Payment Information',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoItem('• Supports blockchain and traditional payment methods'),
            _buildInfoItem('• Blockchain payments use Ethereum network (Ganache test environment)'),
            _buildInfoItem('• Card payments via PayPal Sandbox (no real charge, invoice by email)'),
            _buildInfoItem('• All transaction records are securely stored in the system'),
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
          height: 1.4,
        ),
      ),
    );
  }

  String _getFeeTypeName(FeeType feeType) {
    switch (feeType) {
      case FeeType.managementFee:
        return 'Management Fee';
      case FeeType.maintenanceFee:
        return 'Maintenance Fee';
      case FeeType.lateFee:
        return 'Late Fee';
      case FeeType.other:
        return 'Other Fee';
    }
  }
}
