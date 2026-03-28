// lib/user/face_registration_page.dart
// Resident face enrolment (liveness steps + embedding upload).

import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'package:image/image.dart' as imglib;
import '../services/face_detector_service.dart';
import '../services/ml_service.dart';
import '../utils/image_utils.dart';

enum RegStep {
  checkPosition, // 1. Align and hold (neutral capture)
  blink,         // 2. Blink (liveness)
  smile,         // 3. Smile (liveness)
  processing,    // 4. Processing
  completed      // 5. Done
}

class FaceRegistrationPage extends StatefulWidget {
  const FaceRegistrationPage({Key? key}) : super(key: key);

  @override
  State<FaceRegistrationPage> createState() => _FaceRegistrationPageState();
}

class _FaceRegistrationPageState extends State<FaceRegistrationPage> {
  CameraController? _cameraController;
  final FaceDetectorService _faceDetectorService = FaceDetectorService();
  final MLService _mlService = MLService();
  
  bool _isCameraInitialized = false;
  bool _isDetecting = false; 
  
  // Wizard step
  RegStep _currentStep = RegStep.checkPosition;
  String _instruction = 'Hold still for 2 seconds';
  Color _statusColor = Colors.white;
  
  bool _hasClosedEyes = false; 
  DateTime? _stableStartTime; 
  static const int _positionHoldMs = 2000; 
  static const int _smileHoldMs = 1000;    
  double _holdProgress = 0.0; 
  
  // Captured neutral / liveness samples: image + ML Kit Face
  // CameraImage? _bestImage; // Deprecated
  // Face? _bestFace; // Deprecated
  final List<Map<String, dynamic>> _capturedSamples = []; // Stores { 'image': imglib.Image, 'face': Face }
  
  String _userName = 'Loading...';
  String _unitNumber = '';

  @override
  void initState() {
    super.initState();
    _fetchUserName();
    _initializeCamera();
    _mlService.initialize();
  }

  Future<void> _fetchUserName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final accountDoc = await FirebaseFirestore.instance.collection('accounts').doc(user.uid).get();
      if (accountDoc.exists) {
        final residentId = accountDoc.data()?['residentId'] as String?;
        if (residentId != null) {
          final residentDoc = await FirebaseFirestore.instance.collection('residents').doc(residentId).get();
          if (mounted && residentDoc.exists) {
            setState(() {
              _userName = residentDoc.data()?['fullName'] ?? 'Resident';
              _unitNumber = residentDoc.data()?['unitNumber'] ?? '';
            });
            return;
          }
        }
      }
      if (mounted) setState(() => _userName = 'Unknown');
    } catch (e) {
      debugPrint('Error fetching name: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetectorService.dispose();
    _mlService.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      await _cameraController!.startImageStream(_processCameraImage);

      setState(() => _isCameraInitialized = true);
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  void _processCameraImage(CameraImage image) async {
    if (_isDetecting || _currentStep == RegStep.processing || _currentStep == RegStep.completed) return;
    _isDetecting = true;

    try {
      final faces = await _faceDetectorService.detectFacesFromImage(
        image, 
        _cameraController!.description
      );

      if (faces.isEmpty) {
        _resetStability();
        _updateUI('No face detected', Colors.orange);
      } else if (faces.length > 1) {
        _resetStability();
        _updateUI('Multiple faces detected', Colors.red);
      } else {
        _evaluateStep(faces.first, image);
      }
    } catch (e) {
      debugPrint('Detection error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  void _resetStability() {
    if (_stableStartTime != null) {
      setState(() {
        _stableStartTime = null;
        _holdProgress = 0.0;
      });
    }
  }

  void _evaluateStep(Face face, CameraImage image) {
    final double? rotY = face.headEulerAngleY; 
    final double? rotZ = face.headEulerAngleZ; 
    
    // Strict head pose check
    bool isFaceStraight = (rotY != null && rotZ != null && rotY.abs() <= 10 && rotZ.abs() <= 10);

    if (!isFaceStraight) {
      _resetStability();
      _updateUI('Please look straight ahead', Colors.orange);
      _hasClosedEyes = false; 
      return; 
    }

    switch (_currentStep) {
      case RegStep.checkPosition:
        // Requirement: Neutral face held for 2 seconds
        if (_stableStartTime == null) setState(() => _stableStartTime = DateTime.now());
        
        final duration = DateTime.now().difference(_stableStartTime!).inMilliseconds;
        final progress = (duration / _positionHoldMs).clamp(0.0, 1.0);
        setState(() => _holdProgress = progress);

        // Capture extra sample at 50% progress for robustness
        if (duration > _positionHoldMs * 0.5 && _capturedSamples.isEmpty) {
             _captureSample(image, face);
        }

        if (duration >= _positionHoldMs) {
          // CAPTURE BEST IMAGE AND FACE HERE
          _captureSample(image, face);
          
          _resetStability();
          _updateUI('Step 1: OK!\nNow, blink your eyes', Colors.blue);
          setState(() => _currentStep = RegStep.blink);
        } else {
          _updateUI('Hold still... ${(2 - duration/1000).toStringAsFixed(1)}s', Colors.blueAccent);
        }
        break;

      case RegStep.blink:
        final double? leftEye = face.leftEyeOpenProbability;
        final double? rightEye = face.rightEyeOpenProbability;
        
        if (leftEye == null || rightEye == null) return;

        if (leftEye < 0.2 && rightEye < 0.2) {
          _hasClosedEyes = true;
          _updateUI('Eyes closed... Now open!', Colors.blueAccent);
        } else if (_hasClosedEyes && leftEye > 0.8 && rightEye > 0.8) {
          _captureSample(image, face); // Capture post-blink
          _updateUI('Step 2: Blink Detected!\nNow, smile!', Colors.green);
          setState(() => _currentStep = RegStep.smile);
        } else {
          if (!_hasClosedEyes) _updateUI('Please blink your eyes', Colors.white);
        }
        break;

      case RegStep.smile:
        final double? smileProb = face.smilingProbability;
        bool isSmiling = smileProb != null && smileProb > 0.8;

        if (isSmiling) {
          if (_stableStartTime == null) setState(() => _stableStartTime = DateTime.now());

          final duration = DateTime.now().difference(_stableStartTime!).inMilliseconds;
          final progress = (duration / _smileHoldMs).clamp(0.0, 1.0);
          setState(() => _holdProgress = progress);

          if (duration >= _smileHoldMs) {
            _captureSample(image, face); // Capture smiling
            _updateUI('Step 3: Smile OK!\nSaving...', Colors.greenAccent);
            _processAndSave(); 
          } else {
             _updateUI('Keep smiling... ${(1 - duration/1000).toStringAsFixed(1)}s', Colors.green);
          }
        } else {
          if (_stableStartTime != null) _resetStability();
          _updateUI('Please smile :)', Colors.white);
        }
        break;

      default:
        break;
    }
  }

  void _updateUI(String msg, Color color) {
    if (!mounted) return;
    if (_instruction != msg) {
      setState(() {
        _instruction = msg;
        _statusColor = color;
      });
    }
  }

  void _captureSample(CameraImage image, Face face) {
    try {
      final converted = ImageUtils.convertCameraImage(image);
      if (converted != null) {
        _capturedSamples.add({
          'image': converted,
          'face': face,
        });
        debugPrint('Captured sample #${_capturedSamples.length}');
      }
    } catch (e) {
      debugPrint('Error capturing sample: $e');
    }
  }

  // Use the cached best image (neutral) to generate embedding
  Future<void> _processAndSave() async {
    setState(() => _currentStep = RegStep.processing);

    try {
      if (_capturedSamples.isEmpty) {
        throw Exception('No valid face images captured');
      }

      List<List<double>> allEmbeddings = [];

      // Process all captured samples
      for (var sample in _capturedSamples) {
        final img = sample['image'] as imglib.Image;
        final face = sample['face'] as Face;
        
        // Front Camera -> Rotation -90
        _mlService.setPredictionFromImage(img, face, rotation: -90);
        final embedding = _mlService.predictedData;
        
        if (embedding.isNotEmpty) {
          allEmbeddings.add(embedding);
        }
      }

      if (allEmbeddings.isEmpty) throw Exception('Failed to generate embeddings');

      // Calculate Average Embedding
      int dim = allEmbeddings[0].length;
      List<double> avgEmbedding = List.filled(dim, 0.0);

      for (var emb in allEmbeddings) {
        for (int i = 0; i < dim; i++) {
          avgEmbedding[i] += emb[i];
        }
      }

      for (int i = 0; i < dim; i++) {
        avgEmbedding[i] /= allEmbeddings.length;
      }

      // Important: L2 Normalize the average vector
      // Since _mlService doesn't expose _l2Normalize publicly, we do it here or assume the service handles it if we passed it back?
      // Actually we need to normalize the average ourselves.
      // Let's implement simple normalize here.
      double sumSq = 0.0;
      for (double x in avgEmbedding) sumSq += x * x;
      double norm = 0.0;
      if (sumSq > 0) norm = 1.0 / (math.sqrt(sumSq)); // use math.sqrt
      for (int i = 0; i < dim; i++) avgEmbedding[i] *= norm;


      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'fullName': _userName,     
          'unitNumber': _unitNumber, 
          'faceEmbedding': avgEmbedding,
          'isFaceRegistered': true,
          'faceRegisteredAt': FieldValue.serverTimestamp(),
          'sampleCount': allEmbeddings.length, // Debug info
        }, SetOptions(merge: true));
        
        debugPrint('✅ Face Registered with Multi-Sample Averaging (${allEmbeddings.length} samples)');
        
        if (mounted) {
          setState(() => _currentStep = RegStep.completed);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verification Complete! Face Registered.')),
          );
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) context.pop();
        }
      }
    } catch (e) {
      debugPrint('Registration error: $e');
      _updateUI('Error: $e', Colors.red);
      setState(() {
        _currentStep = RegStep.checkPosition;
        _hasClosedEyes = false;
        _resetStability();
        _capturedSamples.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final circleSize = size.width * 0.8;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        alignment: Alignment.center,
        children: [
          if (_isCameraInitialized && _cameraController != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize!.height,
                  height: _cameraController!.value.previewSize!.width,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),

          ColorFiltered(
            colorFilter: const ColorFilter.mode(Colors.black54, BlendMode.srcOut),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: circleSize,
                    height: circleSize,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_holdProgress > 0 && _currentStep != RegStep.blink && _currentStep != RegStep.processing)
             SizedBox(
               width: circleSize,
               height: circleSize,
               child: CircularProgressIndicator(
                 value: _holdProgress,
                 strokeWidth: 8,
                 color: Colors.greenAccent,
                 backgroundColor: Colors.transparent,
               ),
             ),

          Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _statusColor, width: 4),
            ),
          ),

          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: Column(
              children: [
                if (_currentStep != RegStep.processing && _currentStep != RegStep.completed)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStepDot(0, _currentStep.index >= 0),
                      _buildStepBar(_currentStep.index >= 1),
                      _buildStepDot(1, _currentStep.index >= 1),
                      _buildStepBar(_currentStep.index >= 2),
                      _buildStepDot(2, _currentStep.index >= 2),
                    ],
                  ),
                const SizedBox(height: 20),
                
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _instruction,
                    key: ValueKey<String>(_instruction),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      color: _statusColor,
                      fontSize: 22, 
                      fontWeight: FontWeight.bold,
                      shadows: [
                        const Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 10),
                Text(
                  'Verify you are a real person',
                  style: GoogleFonts.montserrat(color: Colors.white60, fontSize: 12),
                ),

                if (_currentStep == RegStep.processing)
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
              ],
            ),
          ),
          
          Positioned(
            top: 100,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
              child: Text(
                'User: $_userName',
                style: GoogleFonts.robotoMono(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDot(int index, bool active) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: active ? Colors.green : Colors.grey,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildStepBar(bool active) {
    return Container(
      width: 40,
      height: 2,
      color: active ? Colors.green : Colors.grey,
    );
  }
}
