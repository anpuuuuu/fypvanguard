// lib/services/ml_service.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as imglib;
import '../utils/image_utils.dart';

// User Model for Local Use
class User {
  String uid;
  String name;
  String unit;
  List<double> modelData;

  User({required this.uid, required this.name, required this.unit, required this.modelData});
}

class MLService {
  Interpreter? _interpreter;
  // 阈值调整：归一化后，欧氏距离通常在 0 (相同) 到 2 (相反) 之间
  // 0.7 - 0.8 是一个经验值，对应余弦相似度约 0.75 - 0.68
  // 想要"更准确"，可以降低阈值（例如 0.7），减少误识（但可能增加拒识）
  // 想要"更容易通过"，可以增加阈值（例如 0.9）
  double threshold = 0.75; 

  List<double> _predictedData = [];
  List<double> get predictedData => _predictedData;

  Future<void> initialize() async {
    try {
      Delegate? delegate;
      if (Platform.isAndroid) {
        // delegate = GpuDelegateV2(...); // Disabled for emulator stability
      }
      
      var interpreterOptions = InterpreterOptions();
      if (delegate != null) {
        interpreterOptions.addDelegate(delegate);
      }

      _interpreter = await Interpreter.fromAsset('assets/models/mobilefacenet.tflite',
          options: interpreterOptions);
      print('Model loaded successfully');
    } catch (e) {
      print('Failed to load model.');
      print(e);
    }
  }

  // Core function: Process image and face to get embedding
  // Added [rotation] parameter to handle Front (-90) vs Back (90) camera differences
  void setCurrentPrediction(CameraImage cameraImage, Face? face, {int rotation = 90}) {
    if (_interpreter == null) throw Exception('Interpreter is null');
    if (face == null) throw Exception('Face is null');
    
    // 1. Convert CameraImage to imglib.Image
    imglib.Image convertedImage = _convertCameraImage(cameraImage);
    
    // 2. Predict with converted image
    _predictWithImage(convertedImage, face, rotation);
  }

  // Overload: Process pre-converted image
  void setPredictionFromImage(imglib.Image image, Face face, {int rotation = 90}) {
    if (_interpreter == null) throw Exception('Interpreter is null');
    _predictWithImage(image, face, rotation);
  }

  void _predictWithImage(imglib.Image convertedImage, Face face, int rotation) {
    List<double> input = _preProcessImage(convertedImage, face, rotation);

    var inputTensor = input.reshape([1, 112, 112, 3]);
    var outputTensor = List.filled(1 * 192, 0.0).reshape([1, 192]);

    _interpreter?.run(inputTensor, outputTensor);
    
    List<double> output = List<double>.from(outputTensor[0]);
    _predictedData = _l2Normalize(output);
  }

  // L2 Normalization
  List<double> _l2Normalize(List<double> embedding) {
    double sumSq = 0.0;
    for (double x in embedding) {
      sumSq += x * x;
    }
    double norm = sqrt(sumSq);
    if (norm == 0) return embedding; // Handle zero vector
    return embedding.map((e) => e / norm).toList();
  }

  Future<User?> predict(List<User> users) async {
    return _searchResult(users, _predictedData);
  }

  List<double> _preProcess(CameraImage image, Face faceDetected, int rotation) {
    // Legacy support if needed, but we now use _preProcessImage
    imglib.Image convertedImage = _convertCameraImage(image);
    return _preProcessImage(convertedImage, faceDetected, rotation);
  }

  List<double> _preProcessImage(imglib.Image convertedImage, Face faceDetected, int rotation) {
    imglib.Image croppedImage = _cropFaceFromImage(convertedImage, faceDetected, rotation);
    imglib.Image img = imglib.copyResizeCropSquare(croppedImage, size: 112);
    Float32List imageAsList = imageToByteListFloat32(img);
    return imageAsList;
  }

  imglib.Image _cropFace(CameraImage image, Face faceDetected, int rotation) {
     // Legacy
     imglib.Image convertedImage = _convertCameraImage(image);
     return _cropFaceFromImage(convertedImage, faceDetected, rotation);
  }

  imglib.Image _cropFaceFromImage(imglib.Image convertedImage, Face faceDetected, int rotation) {
    // Rotate based on camera (Front: -90, Back: 90)
    var img1 = imglib.copyRotate(convertedImage, angle: rotation);

    double x = faceDetected.boundingBox.left - 10.0;
    double y = faceDetected.boundingBox.top - 10.0;
    double w = faceDetected.boundingBox.width + 10.0;
    double h = faceDetected.boundingBox.height + 10.0;
    
    int ix = x.round();
    int iy = y.round();
    int iw = w.round();
    int ih = h.round();
    
    if (ix < 0) ix = 0;
    if (iy < 0) iy = 0;
    if (ix + iw > img1.width) iw = img1.width - ix;
    if (iy + ih > img1.height) ih = img1.height - iy;
    
    return imglib.copyCrop(img1, x: ix, y: iy, width: iw, height: ih);
  }

  imglib.Image _convertCameraImage(CameraImage image) {
    var img = ImageUtils.convertCameraImage(image);
    if (img == null) throw Exception("Image conversion failed");
    return img;
  }

  Float32List imageToByteListFloat32(imglib.Image image) {
    var convertedBytes = Float32List(1 * 112 * 112 * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;

    for (var i = 0; i < 112; i++) {
      for (var j = 0; j < 112; j++) {
        var pixel = image.getPixel(j, i);
        // Normalization: (val - 128) / 128
        buffer[pixelIndex++] = (pixel.r - 128) / 128;
        buffer[pixelIndex++] = (pixel.g - 128) / 128;
        buffer[pixelIndex++] = (pixel.b - 128) / 128;
      }
    }
    return convertedBytes.buffer.asFloat32List();
  }

  User? _searchResult(List<User> users, List<double> predictedData) {
    if (users.isEmpty) return null;
    double minDist = 999;
    double currDist = 0.0;
    User? predictedResult;

    for (User u in users) {
      currDist = _euclideanDistance(u.modelData, predictedData);
      if (currDist <= threshold && currDist < minDist) {
        minDist = currDist;
        predictedResult = u;
      }
    }
    return predictedResult;
  }

  double _euclideanDistance(List<double>? e1, List<double>? e2) {
    if (e1 == null || e2 == null) return double.infinity;
    double sum = 0.0;
    for (int i = 0; i < e1.length; i++) {
      sum += pow((e1[i] - e2[i]), 2);
    }
    return sqrt(sum);
  }
  
  double euclideanDistance(List<double> e1, List<double> e2) {
    return _euclideanDistance(e1, e2);
  }

  void dispose() {
    _interpreter?.close();
  }
}
