// lib/payment/ui/paypal_checkout_page.dart
// Pay with PayPal Sandbox – create order, then open PayPal inside the app (WebView) to log in and approve

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/transaction_model.dart';
import 'paypal_webview_page.dart';
import 'paypal_complete_page.dart';

class PayPalCheckoutPage extends StatefulWidget {
  final double amount;
  final FeeType feeType;
  final String? feeTypeKey;
  final String feeTypeName;
  final String description;

  const PayPalCheckoutPage({
    Key? key,
    required this.amount,
    required this.feeType,
    this.feeTypeKey,
    required this.feeTypeName,
    required this.description,
  }) : super(key: key);

  @override
  State<PayPalCheckoutPage> createState() => _PayPalCheckoutPageState();
}

class _PayPalCheckoutPageState extends State<PayPalCheckoutPage> {
  bool _isLoading = false;
  String? _error;

  Future<void> _openPayPal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _error = 'Please log in first');
      return;
    }

    final accountDoc = await FirebaseFirestore.instance
        .collection('accounts')
        .doc(user.uid)
        .get();
    final residentId = accountDoc.data()?['residentId'] as String? ?? user.uid;
    final feeTypeKey = widget.feeTypeKey ?? widget.feeType.toString().split('.').last;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('createPayPalOrder');
      final result = await callable.call<Map<dynamic, dynamic>>({
        'amount': widget.amount,
        'currency': 'MYR',
        'returnUrl': 'vanguardfyp://paypal-return',
        'cancelUrl': 'vanguardfyp://paypal-cancel',
        'userId': user.uid,
        'residentId': residentId,
        'feeType': feeTypeKey,
        'feeTypeKey': feeTypeKey,
        'feeTypeName': widget.feeTypeName,
        'description': widget.description.isEmpty ? null : widget.description,
      });

      final data = result.data;
      final orderId = data['orderId'] as String?;
      final approvalUrl = data['approvalUrl'] as String?;

      if (orderId == null || approvalUrl == null) {
        setState(() {
          _error = 'Invalid response from server';
          _isLoading = false;
        });
        return;
      }

      setState(() => _isLoading = false);

      if (!mounted) return;
      final returnedOrderId = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => PayPalWebViewPage(approvalUrl: approvalUrl),
        ),
      );

      if (!mounted || returnedOrderId == null || returnedOrderId.isEmpty) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PayPalCompletePage(
            orderId: returnedOrderId,
            amount: widget.amount,
            feeType: widget.feeType,
            feeTypeKey: feeTypeKey,
            feeTypeName: widget.feeTypeName,
            description: widget.description,
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _error = e.message ?? 'PayPal error: ${e.code}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
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
          'Pay with PayPal',
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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Amount',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'RM ${widget.amount.toStringAsFixed(2)}',
                      style: GoogleFonts.montserrat(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.feeTypeName,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'PayPal Sandbox',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PayPal will open inside the app. Log in with your sandbox account (e.g. sb-xxx@personal.example.com) and approve the payment. No real money is charged.',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      color: Colors.blue.shade900,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _openPayPal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003087),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Pay with PayPal RM ${widget.amount.toStringAsFixed(2)}',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
