// lib/payment/ui/payment_confirmation.dart
// Payment confirmation page

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import 'payment_method_selection.dart';

class PaymentConfirmationPage extends StatefulWidget {
  final double amount;
  final FeeType feeType;
  final String description;
  final PaymentMethod paymentMethod;

  const PaymentConfirmationPage({
    Key? key,
    required this.amount,
    required this.feeType,
    required this.description,
    required this.paymentMethod,
  }) : super(key: key);

  @override
  State<PaymentConfirmationPage> createState() => _PaymentConfirmationPageState();
}

class _PaymentConfirmationPageState extends State<PaymentConfirmationPage> {
  bool _isProcessing = false;

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

  String _getPaymentMethodName(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.blockchain:
        return 'Blockchain Payment';
      case PaymentMethod.stripe:
        return 'Credit/Debit Card';
      case PaymentMethod.paypal:
        return 'PayPal';
    }
  }

  void _proceedToPayment() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentMethodSelectionPage(
          amount: widget.amount,
          feeType: widget.feeType,
          feeTypeKey: widget.feeType.toString().split('.').last,
          feeTypeName: _getFeeTypeName(widget.feeType),
          description: widget.description,
          paymentMethod: widget.paymentMethod,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Confirm Payment',
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
            // Payment summary card
            Card(
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
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSummaryRow('Fee Type', _getFeeTypeName(widget.feeType)),
                    const Divider(height: 24),
                    _buildSummaryRow('Payment Method', _getPaymentMethodName(widget.paymentMethod)),
                    const Divider(height: 24),
                    _buildSummaryRow('Amount', 'RM ${widget.amount.toStringAsFixed(2)}', isAmount: true),
                    if (widget.description.isNotEmpty) ...[
                      const Divider(height: 24),
                      _buildSummaryRow('Description', widget.description),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Payment method specific information
            if (widget.paymentMethod == PaymentMethod.blockchain)
              _buildBlockchainInfo()
            else
              _buildTraditionalPaymentInfo(),

            const SizedBox(height: 32),

            // Confirm button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _proceedToPayment,
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
                        'Confirm and Proceed',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 12),

            // Cancel button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isAmount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: isAmount ? 20 : 14,
            fontWeight: isAmount ? FontWeight.w700 : FontWeight.w600,
            color: isAmount ? Colors.red.shade700 : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildBlockchainInfo() {
    return Card(
      elevation: 1,
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
                Text(
                  'Blockchain Payment',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'You will be asked to provide your Ethereum wallet address and private key to authorize the transaction. The transaction will be processed on the Ganache test network.',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: Colors.orange.shade900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTraditionalPaymentInfo() {
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
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Secure Payment',
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
              'You will be asked to enter your credit/debit card details. If your bank requires 3D Secure authentication, you will be prompted to enter your password.',
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
}
