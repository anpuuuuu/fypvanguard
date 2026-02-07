// lib/payment/ui/paypal_complete_page.dart
// After user returns from PayPal – capture order and create transaction + invoice

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/transaction_model.dart';
import '../controllers/payment_controller.dart';

class PayPalCompletePage extends StatefulWidget {
  final String orderId;
  final double amount;
  final FeeType feeType;
  final String feeTypeKey;
  final String feeTypeName;
  final String description;

  const PayPalCompletePage({
    Key? key,
    required this.orderId,
    required this.amount,
    required this.feeType,
    required this.feeTypeKey,
    required this.feeTypeName,
    required this.description,
  }) : super(key: key);

  @override
  State<PayPalCompletePage> createState() => _PayPalCompletePageState();
}

class _PayPalCompletePageState extends State<PayPalCompletePage> {
  final PaymentController _controller = PaymentController();
  bool _completed = false;
  bool _loading = true;
  String? _error;
  String? _transactionId;

  @override
  void initState() {
    super.initState();
    _controller.initialize();
    _captureAndComplete();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _captureAndComplete() async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('capturePayPalOrder');
      final result = await callable.call<Map<dynamic, dynamic>>({
        'orderId': widget.orderId,
      });

      final data = result.data;
      final success = data['success'] as bool? ?? false;
      final pendingOrder = data['pendingOrder'] as Map<dynamic, dynamic>?;

      if (!success || pendingOrder == null) {
        setState(() {
          _error = 'Payment could not be completed. Try again.';
          _loading = false;
        });
        return;
      }

      final userId = pendingOrder['userId'] as String?;
      final residentId = pendingOrder['residentId'] as String? ?? userId;
      final amount = (pendingOrder['amount'] as num?)?.toDouble() ?? widget.amount;
      final feeTypeKey = pendingOrder['feeTypeKey'] as String? ?? widget.feeTypeKey;
      final feeTypeName = pendingOrder['feeTypeName'] as String? ?? widget.feeTypeName;
      final description = pendingOrder['description'] as String?;

      if (userId == null) {
        setState(() {
          _error = 'Invalid order data.';
          _loading = false;
        });
        return;
      }

      final String residentIdVal = residentId ?? userId;
      final String feeTypeKeyVal = feeTypeKey ?? widget.feeTypeKey;
      final String feeTypeNameVal = feeTypeName ?? widget.feeTypeName;

      final transaction = await _controller.completePayPalPaymentFromCapture(
        userId: userId,
        residentId: residentIdVal,
        amount: amount,
        feeTypeKey: feeTypeKeyVal,
        feeTypeName: feeTypeNameVal,
        orderId: widget.orderId,
        description: description,
      );

      if (mounted) {
        setState(() {
          _completed = true;
          _loading = false;
          _transactionId = transaction.id;
        });
      }
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _error = e.message ?? 'Error: ${e.code}';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
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
          _completed ? 'Payment complete' : 'Completing payment',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        automaticallyImplyLeading: !_loading,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _loading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    Text(
                      'Completing your payment...',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Back'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 80,
                        color: Colors.green.shade600,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Payment successful',
                        style: GoogleFonts.montserrat(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'RM ${widget.amount.toStringAsFixed(2)}',
                        style: GoogleFonts.montserrat(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      if (_transactionId != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Transaction: $_transactionId',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context, true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Done',
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
}
