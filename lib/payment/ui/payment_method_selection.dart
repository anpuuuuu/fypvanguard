// lib/payment/ui/payment_method_selection.dart
// Payment method selection page

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../controllers/payment_controller.dart';
import '../services/blockchain_service.dart';
import 'credit_card_input.dart';
import 'blockchain_payment_page.dart';
import 'paypal_checkout_page.dart';

class PaymentMethodSelectionPage extends StatefulWidget {
  final double amount;
  final FeeType feeType;
  final String? feeTypeKey;  // For matching pending fees (e.g. 'maintenance', 'insurance')
  final String feeTypeName;  // Display name from admin config
  final String description;
  final PaymentMethod? paymentMethod; // Pre-selected payment method

  const PaymentMethodSelectionPage({
    Key? key,
    required this.amount,
    required this.feeType,
    this.feeTypeKey,
    required this.feeTypeName,
    required this.description,
    this.paymentMethod,
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


  @override
  void initState() {
    super.initState();
    _controller.initialize();
    // Pre-select payment method if provided
    if (widget.paymentMethod != null) {
      _selectedMethod = widget.paymentMethod;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (_selectedMethod == null) {
      _showError('Please select a payment method');
      return;
    }

    if (_selectedMethod == PaymentMethod.blockchain) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BlockchainPaymentPage(
            amount: widget.amount,
            feeType: widget.feeType,
            feeTypeKey: widget.feeTypeKey,
            feeTypeName: widget.feeTypeName,
            description: widget.description,
          ),
        ),
      );
      if (result == true && mounted) Navigator.pop(context, true);
      return;
    }

    if (_selectedMethod == PaymentMethod.paypalAccount) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PayPalCheckoutPage(
            amount: widget.amount,
            feeType: widget.feeType,
            feeTypeKey: widget.feeTypeKey,
            feeTypeName: widget.feeTypeName,
            description: widget.description,
          ),
        ),
      );
      if (result == true && mounted) Navigator.pop(context, true);
      return;
    }

    // Credit/Debit card (PayPal Sandbox form)
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreditCardInputPage(
          amount: widget.amount,
          feeType: widget.feeType,
          feeTypeKey: widget.feeTypeKey,
          feeTypeName: widget.feeTypeName,
          description: widget.description,
        ),
      ),
    );
    if (result == true && mounted) Navigator.pop(context, true);
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showErrorWithRetry(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () {
              // Retry payment
              _processPayment();
            },
          ),
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
          'Select Payment Method',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            // Go back to payment home
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Payment summary card
            _buildSummaryCard(),

            const SizedBox(height: 24),

            // Payment method selection
            Text(
              'Select Payment Method',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 16),

            // Blockchain payment option
            _buildPaymentMethodCard(
              icon: Icons.account_balance_wallet,
              title: 'Blockchain Payment',
              subtitle: 'Using Ethereum network (Ganache test environment)',
              method: PaymentMethod.blockchain,
              color: Colors.orange,
            ),

            const SizedBox(height: 12),

            // PayPal Sandbox – log in with PayPal account
            _buildPaymentMethodCard(
              icon: Icons.account_balance_wallet,
              title: 'Pay with PayPal (Sandbox account)',
              subtitle: 'Log in with your PayPal sandbox account to pay',
              method: PaymentMethod.paypalAccount,
              color: const Color(0xFF003087),
            ),

            const SizedBox(height: 12),

            // Credit/Debit card (simulated)
            _buildPaymentMethodCard(
              icon: Icons.credit_card,
              title: 'Credit/Debit Card',
              subtitle: 'Enter card details (simulated, no real charge)',
              method: PaymentMethod.paypal,
              color: Colors.blue,
            ),

            const SizedBox(height: 24),

            // Payment method info
            if (_selectedMethod == PaymentMethod.blockchain)
              _buildBlockchainInfo()
            else if (_selectedMethod == PaymentMethod.paypalAccount)
              _buildPayPalAccountInfo()
            else if (_selectedMethod == PaymentMethod.paypal)
              _buildPayPalInfo(),

            const SizedBox(height: 24),

            // Payment button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing || _selectedMethod == null ? null : _processPayment,
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
                        _selectedMethod == PaymentMethod.blockchain
                            ? 'Go to Blockchain Payment RM ${widget.amount.toStringAsFixed(2)}'
                            : _selectedMethod == PaymentMethod.paypalAccount
                                ? 'Pay with PayPal'
                                : _selectedMethod == PaymentMethod.paypal
                                    ? 'Enter Card Details'
                                    : 'Confirm Payment RM ${widget.amount.toStringAsFixed(2)}',
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
              'Payment Summary',
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
                  'Fee Type',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  widget.feeTypeName,
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
                  'Amount',
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
                'Description',
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

  Widget _buildBlockchainInfo() {
    return Card(
      elevation: 2,
      color: Colors.orange.shade50,
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
                Icon(Icons.info_outline, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Blockchain Payment Information',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'After clicking "Confirm Payment", you will enter the blockchain payment page where you can choose:',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: Colors.orange.shade900,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            _buildInfoItem('• Use pre-configured Ganache test accounts (each has 100 ETH)'),
            _buildInfoItem('• Manually enter address and private key (advanced)'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Tip: Using pre-configured accounts is the simplest and fastest, no need to manually enter complex addresses.',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  color: Colors.orange.shade800,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: Colors.orange.shade900,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayPalAccountInfo() {
    return Card(
      elevation: 2,
      color: const Color(0xFF003087).withOpacity(0.08),
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
                Icon(Icons.info_outline, color: const Color(0xFF003087)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pay with your PayPal Sandbox account',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF003087),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'PayPal opens inside the app. Log in with your sandbox account (e.g. sb-xxx@personal.example.com) and approve the payment. No real money is charged.',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: Colors.grey[800],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayPalInfo() {
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
                Expanded(
                  child: Text(
                    'PayPal Sandbox – Card Payment',
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
            Text(
              'Enter a valid card number (e.g. 4012888888881881). No real money is deducted. Payment will complete successfully and an invoice will be sent to your email.',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: Colors.blue.shade900,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
