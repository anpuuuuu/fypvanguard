// lib/security/qr_scanner_page.dart
// Security: scan visitor QR passes.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/qr_service.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({Key? key}) : super(key: key);

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    returnImage: false,
  );
  final QrService _qrService = QrService();
  
  bool _isProcessing = false;
  bool _torchEnabled = false;
  bool _hasPermission = true;
  String? _errorMessage;
  bool _showManualInput = false; // Dev: manual QR string input

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    try {
      // mobile_scanner requests permission; start() reflects availability
      await _controller.start();
      if (mounted) {
        setState(() {
          _hasPermission = true;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasPermission = false;
          _errorMessage = 'Camera permission denied or camera unavailable. Please grant camera permission in settings.';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;
    
    setState(() => _isProcessing = true);
    
    final qrCode = barcode.rawValue!;
    final result = await _qrService.verifyQrCode(qrCode);
    
    if (!mounted) return;
    
    if (result.isValid) {
      await _showVisitorDialog(result);
    } else {
      _showErrorDialog(result.errorMessage ?? 'Invalid QR code');
    }
    
    setState(() => _isProcessing = false);
  }

  Future<void> _showVisitorDialog(QrVerificationResult result) async {
    final visitorData = result.visitorData!;
    final visitorId = result.visitorId!;
    final currentStatus = result.currentStatus!;
    
    final visitorName = visitorData['visitorName'] as String? ?? 'Unknown';
    final entryType = visitorData['entryType'] as String? ?? '';
    final phoneNumber = visitorData['phoneNumber'] as String? ?? '';
    final vehiclePlate = visitorData['vehiclePlate'] as String?;
    final residentId = visitorData['residentId'] as String? ?? '';
    
    // Load host resident for display
    String residentInfo = 'Loading...';
    try {
      final residentDoc = await FirebaseFirestore.instance
          .collection('residents')
          .doc(residentId)
          .get();
      if (residentDoc.exists) {
        final data = residentDoc.data()!;
        final name = data['fullName'] as String? ?? 'Unknown';
        final unit = data['unitNumber'] as String? ?? 'N/A';
        residentInfo = '$name (Unit $unit)';
      }
    } catch (e) {
      residentInfo = 'Unknown';
    }
    
    // Next action from current visitor status
    String actionText;
    String actionDescription;
    Color actionColor;
    VoidCallback? onAction;
    
    if (currentStatus == 'approved') {
      actionText = 'Check In';
      actionDescription = 'Visitor will be marked as entered';
      actionColor = Colors.green;
      onAction = () async {
        await _qrService.checkInVisitor(visitorId, entryType);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$visitorName checked in successfully!', 
                  style: GoogleFonts.montserrat()),
              backgroundColor: Colors.green.shade400,
            ),
          );
        }
      };
    } else if (currentStatus == 'checked-in') {
      actionText = 'Check Out';
      actionDescription = 'Visitor will be marked as left';
      actionColor = Colors.blue;
      onAction = () async {
        await _qrService.checkOutVisitor(visitorId);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$visitorName checked out successfully!', 
                  style: GoogleFonts.montserrat()),
              backgroundColor: Colors.blue.shade400,
            ),
          );
        }
      };
    } else {
      actionText = 'Close';
      actionDescription = 'No action available';
      actionColor = Colors.grey;
      onAction = () => Navigator.of(context).pop();
    }
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Valid Pass',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Visitor summary card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Visitor name
                    Text(
                      visitorName,
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Entry type
                    _buildInfoRow(
                      Icons.directions_walk,
                      'Type',
                      entryType == 'walk-in' ? 'Walk-in' : 'By Car',
                      entryType == 'walk-in' ? Colors.blue : Colors.orange,
                    ),
                    
                    // Phone
                    _buildInfoRow(Icons.phone, 'Phone', phoneNumber, Colors.grey),
                    
                    // Vehicle plate (if any)
                    if (vehiclePlate != null && vehiclePlate.isNotEmpty)
                      _buildInfoRow(Icons.directions_car, 'Plate', vehiclePlate, Colors.red),
                    
                    // Host resident
                    _buildInfoRow(Icons.home, 'Resident', residentInfo, Colors.purple),
                    
                    // Current status
                    _buildInfoRow(
                      Icons.info_outline,
                      'Status',
                      currentStatus.toUpperCase().replaceAll('-', ' '),
                      currentStatus == 'approved' ? Colors.green : Colors.blue,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Parking note (car entry only)
              if (entryType == 'car' && currentStatus == 'approved')
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Max 4 hours parking, must leave by 2 AM',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: GoogleFonts.montserrat(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: onAction,
            child: Text(actionText, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: GoogleFonts.montserrat(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red.shade700, size: 28),
            const SizedBox(width: 12),
            Text(
              'Invalid Pass',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  /// Dev only: paste QR string (e.g. emulator without camera).
  void _showManualInputDialog() {
    final textController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.keyboard, color: Colors.blue.shade700, size: 24),
            const SizedBox(width: 12),
            Text(
              'Manual QR Input',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter QR code string (for testing on emulator)',
              style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              decoration: InputDecoration(
                hintText: 'Paste QR code string here',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.qr_code),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: GoogleFonts.montserrat()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final qrCode = textController.text.trim();
              if (qrCode.isEmpty) {
                Navigator.of(context).pop();
                return;
              }
              
              Navigator.of(context).pop();
              
              if (_isProcessing) return;
              setState(() => _isProcessing = true);
              
              final result = await _qrService.verifyQrCode(qrCode);
              
              if (!mounted) return;
              
              if (result.isValid) {
                await _showVisitorDialog(result);
              } else {
                _showErrorDialog(result.errorMessage ?? 'Invalid QR code');
              }
              
              setState(() => _isProcessing = false);
            },
            child: Text('Verify', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // No camera permission: error UI
    if (!_hasPermission) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: Colors.red.shade700,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'Scan Visitor Pass',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => GoRouter.of(context).go('/security'),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.camera_alt_outlined,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 24),
                Text(
                  'Camera Permission Required',
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'This app needs camera access to scan QR codes. Please grant camera permission in your device settings.',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: const Icon(Icons.settings),
                  label: Text(
                    'Open Settings',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () async {
                    // Retry camera / permission
                    await _checkCameraPermission();
                  },
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => GoRouter.of(context).go('/security'),
                  child: Text(
                    'Go Back',
                    style: GoogleFonts.montserrat(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Scan Visitor Pass',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/security'),
        ),
        actions: [
          // Torch
          IconButton(
            icon: Icon(_torchEnabled ? Icons.flash_on : Icons.flash_off),
            onPressed: () {
              _controller.toggleTorch();
              setState(() => _torchEnabled = !_torchEnabled);
            },
          ),
          // Switch camera
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera preview
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          
          // Scan frame overlay
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  // Corner accents
                  Positioned(top: -2, left: -2, child: _buildCorner(true, true)),
                  Positioned(top: -2, right: -2, child: _buildCorner(true, false)),
                  Positioned(bottom: -2, left: -2, child: _buildCorner(false, true)),
                  Positioned(bottom: -2, right: -2, child: _buildCorner(false, false)),
                ],
              ),
            ),
          ),
          
          // Processing overlay
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          
          // Hint + manual input (dev)
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    'Point camera at visitor\'s QR code',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Dev: manual QR input
                TextButton.icon(
                  icon: const Icon(Icons.keyboard, color: Colors.white70),
                  label: Text(
                    'Manual Input (Dev)',
                    style: GoogleFonts.montserrat(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  onPressed: () => _showManualInputDialog(),
                ),
              ],
            ),
          ),
        ],
      ),
      
      // Bottom navigation
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        selectedItemColor: Colors.red.shade700,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.montserrat(fontSize: 12),
        unselectedLabelStyle: GoogleFonts.montserrat(fontSize: 12),
        onTap: (i) {
          switch (i) {
            case 0:
              GoRouter.of(context).go('/security');
              break;
            case 1:
              // Already on scan tab
              break;
            case 2:
              GoRouter.of(context).go('/security/visitorTracking');
              break;
            case 3:
              GoRouter.of(context).go('/security/visitorApproval');
              break;
            case 4:
              GoRouter.of(context).go('/security/maintenanceReview');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Scan'),
          BottomNavigationBarItem(icon: Icon(Icons.person_pin), label: 'Tracking'),
          BottomNavigationBarItem(icon: Icon(Icons.how_to_reg), label: 'Approve'),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Review'),
        ],
      ),
    );
  }

  Widget _buildCorner(bool isTop, bool isLeft) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? BorderSide(color: Colors.red.shade700, width: 4) : BorderSide.none,
          bottom: !isTop ? BorderSide(color: Colors.red.shade700, width: 4) : BorderSide.none,
          left: isLeft ? BorderSide(color: Colors.red.shade700, width: 4) : BorderSide.none,
          right: !isLeft ? BorderSide(color: Colors.red.shade700, width: 4) : BorderSide.none,
        ),
      ),
    );
  }
}
