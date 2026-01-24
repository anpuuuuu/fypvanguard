// lib/services/face_detector_service.dart
// 负责使用 ML Kit 检测人脸

import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/services.dart';

class FaceDetectorService {
  late FaceDetector _faceDetector;

  FaceDetectorService() {
    final options = FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableContours: true,
      enableClassification: true,
      enableLandmarks: true,
    );
    _faceDetector = FaceDetector(options: options);
  }

  Future<List<Face>> detectFacesFromImage(CameraImage image, CameraDescription camera) async {
    final inputImage = _inputImageFromCameraImage(image, camera);
    if (inputImage == null) return [];
    
    try {
      return await _faceDetector.processImage(inputImage);
    } catch (e) {
      debugPrint('Error detecting faces: $e');
      return [];
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image, CameraDescription camera) {
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = _orientations[DeviceOrientation.portraitUp];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    // Android: 将 YUV420 转换为 NV21
    if (Platform.isAndroid && image.format.group == ImageFormatGroup.yuv420) {
      return _processAndroidImage(image, rotation);
    } 
    
    // iOS: BGRA8888
    if (Platform.isIOS && image.format.group == ImageFormatGroup.bgra8888) {
      return InputImage.fromBytes(
        bytes: image.planes[0].bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    }

    return null;
  }

  // Android 专用：YUV_420_888 -> NV21 转换
  InputImage _processAndroidImage(CameraImage image, InputImageRotation rotation) {
    final int width = image.width;
    final int height = image.height;
    
    // Img.planes[0] : Y
    // Img.planes[1] : U
    // Img.planes[2] : V
    
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    
    final int yLen = yPlane.bytes.length;
    final int uvLen = uPlane.bytes.length; // U 和 V 长度通常相同
    
    // NV21 格式大小 = Y + UV = width*height + width*height/2
    // 但考虑到 stride 可能有 padding，我们直接分配足够大的空间
    final int totalSize = yLen + (uvLen * 2); 
    final Uint8List bytes = Uint8List(totalSize);
    
    // 1. 复制 Y 平面 (Luma)
    // 必须考虑 rowStride，如果有 padding 需要逐行复制
    // 如果 rowStride == width，可以直接块复制
    if (yPlane.bytesPerRow == width) {
        bytes.setRange(0, yLen, yPlane.bytes);
    } else {
        int srcOffset = 0;
        int dstOffset = 0;
        for (int i = 0; i < height; i++) {
            // 复制一行有效数据
            bytes.setRange(dstOffset, dstOffset + width, yPlane.bytes.sublist(srcOffset, srcOffset + width));
            srcOffset += yPlane.bytesPerRow;
            dstOffset += width;
        }
    }
    
    // 2. 交叉复制 V 和 U 平面 (Chroma) -> NV21 是 V, U 交替
    // NV21: YYYYYYYY VUVU
    // 注意：camera 插件的 planes[1] 是 U, planes[2] 是 V
    // 还要注意 pixelStride。如果是 2，说明 UV 是已经交错的？
    
    int dstIndex = width * height; // Y 数据之后
    final int uvRowStride = uPlane.bytesPerRow;
    final int uvPixelStride = uPlane.bytesPerPixel!;
    
    // UV 高度是图像高度的一半
    for (int y = 0; y < height / 2; y++) {
      for (int x = 0; x < width / 2; x++) {
        // 计算在源 buffer 中的位置
        final int srcIndex = (y * uvRowStride) + (x * uvPixelStride);
        
        // 安全检查
        if (srcIndex >= uPlane.bytes.length || srcIndex >= vPlane.bytes.length) continue;
        
        final byteV = vPlane.bytes[srcIndex];
        final byteU = uPlane.bytes[srcIndex];
        
        // NV21: V first, then U
        if (dstIndex < bytes.length) bytes[dstIndex++] = byteV;
        if (dstIndex < bytes.length) bytes[dstIndex++] = byteU;
      }
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(width.toDouble(), height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: width, // NV21 紧凑排列
      ),
    );
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  void dispose() {
    _faceDetector.close();
  }
}