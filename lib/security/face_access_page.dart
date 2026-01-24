// lib/security/face_access_page.dart
// 保安端：人脸识别门禁系统 (Refactored to match Reference Logic)

import 'dart:async';
import 'dart:io'; 
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../services/face_detector_service.dart';
import '../services/ml_service.dart';

// Adapter to match MLService's User model
extension UserAdapter on User {
  static User fromFirestore(String uid, Map<String, dynamic> data) {
    List<double> embedding = [];
    if (data['faceEmbedding'] != null) {
      embedding = (data['faceEmbedding'] as List).map((e) => (e as num).toDouble()).toList();
    }
    return User(
      uid: uid,
      name: data['fullName'] ?? 'Unknown',
      unit: data['unitNumber'] ?? 'N/A',
      modelData: embedding,
    );
  }
}

class FaceAccessPage extends StatefulWidget {
  const FaceAccessPage({super.key});

  @override
  State<FaceAccessPage> createState() => _FaceAccessPageState();
}

class _FaceAccessPageState extends State<FaceAccessPage> {
  CameraController? _cameraController;
  final FaceDetectorService _faceDetectorService = FaceDetectorService();
  final MLService _mlService = MLService();
  
  bool _isCameraInitialized = false;
  bool _isProcessing = false; 
  bool _isLoadingData = true; 
  
  List<User> _registeredUsers = [];
  List<Face> _faces = [];
  
  String? _identifiedName;
  double _currentDistance = 0.0;
  bool _accessGranted = false;
  Timer? _resetTimer;
  
  // Anti-spoofing / Stability
  int _consecutiveMatches = 0;
  String? _lastMatchedUid;
  // 增加连续匹配帧数，牺牲一点速度换取极高的准确率和防抖动
  static const int _requiredConsecutiveMatches = 2; 

  @override
  void initState() {
    super.initState();
    _loadRegisteredUsers();
    _initializeCamera();
    _mlService.initialize();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetectorService.dispose();
    _mlService.dispose();
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRegisteredUsers() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('isFaceRegistered', isEqualTo: true)
          .get();

      final users = <User>[];
      for (var doc in snap.docs) {
        final data = doc.data();
        if (data['faceEmbedding'] != null) {
          users.add(UserAdapter.fromFirestore(doc.id, data));
        }
      }

      if (mounted) {
        setState(() {
          _registeredUsers = users;
          _isLoadingData = false;
        });
        debugPrint('Loaded ${users.length} registered faces.');
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      await _cameraController!.startImageStream(_processCameraImage);

      setState(() => _isCameraInitialized = true);
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  void _processCameraImage(CameraImage image) async {
    if (_isProcessing || _accessGranted) return;
    _isProcessing = true;

    try {
      // 1. Detect Faces
      final faces = await _faceDetectorService.detectFacesFromImage(
        image, 
        _cameraController!.description
      );

      if (mounted) setState(() => _faces = faces);

      if (faces.isEmpty) {
        _resetState();
        return;
      }

      final face = faces.first; 

      // 2. ML Service: Set Current Prediction (Preprocess & Inference)
      // This internally crops, resizes, normalizes, and runs TFLite
      _mlService.setCurrentPrediction(image, face);
      
      // 3. Search for Match
      final User? matchUser = await _mlService.predict(_registeredUsers);
      
      // Calculate min distance for debug display
      double minD = 999;
      if (matchUser != null) {
        minD = _mlService.euclideanDistance(matchUser.modelData, _mlService.predictedData);
      } else {
         // Find nearest even if not match
         for (var u in _registeredUsers) {
            double d = _mlService.euclideanDistance(u.modelData, _mlService.predictedData);
            if (d < minD) minD = d;
         }
      }
      
      if (mounted) setState(() => _currentDistance = minD);

      if (matchUser != null) {
        if (_lastMatchedUid == matchUser.uid) {
          _consecutiveMatches++; 
        } else {
          _consecutiveMatches = 1; 
          _lastMatchedUid = matchUser.uid;
        }

        if (_consecutiveMatches >= _requiredConsecutiveMatches) {
          _grantAccess(matchUser);
        }
      } else {
        _consecutiveMatches = 0;
        _lastMatchedUid = null;
        if (mounted && !_accessGranted) {
          setState(() => _identifiedName = "Unknown");
        }
      }

    } catch (e) {
      debugPrint('Recognition loop error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  void _resetState() {
    _consecutiveMatches = 0;
    _lastMatchedUid = null;
    if (mounted && _identifiedName != null && !_accessGranted) {
       setState(() => _identifiedName = null);
    }
    _isProcessing = false;
  }

  void _grantAccess(User user) {
    if (_accessGranted) return;

    setState(() {
      _accessGranted = true;
      _identifiedName = user.name;
    });

    FirebaseFirestore.instance.collection('access_logs').add({
      'residentId': user.uid,
      'name': user.name,
      'unit': user.unit,
      'entryType': 'face',
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'granted',
    });

    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _accessGranted = false;
          _identifiedName = null;
          _consecutiveMatches = 0;
          _lastMatchedUid = null;
          _faces = []; 
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Face Access Control'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          if (_isCameraInitialized && _cameraController != null)
             LayoutBuilder(
               builder: (context, constraints) {
                 final previewSize = _cameraController!.value.previewSize!;
                 // Android: Camera is Landscape, Screen is Portrait. Swap W/H.
                 final double imgWidth = Platform.isAndroid ? previewSize.height : previewSize.width;
                 final double imgHeight = Platform.isAndroid ? previewSize.width : previewSize.height;

                 return Stack(
                   fit: StackFit.expand,
                   children: [
                     FittedBox(
                       fit: BoxFit.cover,
                       child: SizedBox(
                         width: imgWidth,
                         height: imgHeight,
                         child: CameraPreview(_cameraController!),
                       ),
                     ),
                     if (_faces.isNotEmpty)
                       CustomPaint(
                         painter: FacePainter(
                           faces: _faces,
                           imageSize: Size(imgWidth, imgHeight),
                           widgetSize: Size(constraints.maxWidth, constraints.maxHeight),
                         ),
                       ),
                   ],
                 );
               },
             )
          else
            const Center(child: CircularProgressIndicator()),

          if (_identifiedName != null || _accessGranted)
            Positioned(
              top: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: _accessGranted 
                      ? const Color(0xE64CAF50) 
                      : const Color(0xCCF44336), 
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black26)],
                ),
                child: Column(
                  children: [
                    Icon(
                      _accessGranted ? Icons.check_circle : Icons.warning,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _accessGranted ? 'Access Granted' : 'Unknown Person',
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_accessGranted) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Welcome, $_identifiedName',
                        style: GoogleFonts.montserrat(color: Colors.white, fontSize: 18),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Diff: ${_currentDistance.toStringAsFixed(3)}',
                      style: GoogleFonts.robotoMono(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          
          if (_identifiedName == null && !_accessGranted && _registeredUsers.isNotEmpty)
             Positioned(
              bottom: 150,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    'Diff: ${_currentDistance.toStringAsFixed(3)}',
                    style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),

          if (_isLoadingData)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final Size widgetSize;

  FacePainter({
    required this.faces,
    required this.imageSize,
    required this.widgetSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.greenAccent;

    // ML Kit returns coordinates based on imageSize (e.g., 720x1280)
    // We need to scale them to widgetSize (screen size)
    
    double scaleX = widgetSize.width / imageSize.width;
    double scaleY = widgetSize.height / imageSize.height;

    for (var face in faces) {
      final rect = face.boundingBox;
      final double left = rect.left * scaleX;
      final double top = rect.top * scaleY;
      final double right = rect.right * scaleX;
      final double bottom = rect.bottom * scaleY;
      
      // 1. 计算映射后的矩形
      final mappedRect = Rect.fromLTRB(left, top, right, bottom);
      
      // 2. 强制转为正方形 (取长宽最大值)
      final double size = math.max(mappedRect.width, mappedRect.height);
      final double centerX = mappedRect.center.dx;
      final double centerY = mappedRect.center.dy;
      
      final squareRect = Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: size,
        height: size,
      );

      // 3. 画圆角正方形 (更美观)
      canvas.drawRRect(
        RRect.fromRectAndRadius(squareRect, const Radius.circular(12)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) => true;
}
