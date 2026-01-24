// lib/utils/image_utils.dart
// 集成了更健壮的 YUV420 转换算法

import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class ImageUtils {
  
  static img.Image? convertCameraImage(CameraImage image) {
    try {
      if (image.format.group == ImageFormatGroup.yuv420) {
        return _convertYUV420(image);
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        return _convertBGRA8888(image);
      }
      return null;
    } catch (e) {
      print('Image conversion error: $e');
      return null;
    }
  }

  static img.Image _convertBGRA8888(CameraImage image) {
    return img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: image.planes[0].bytes.buffer,
      order: img.ChannelOrder.bgra,
    );
  }

  // --- 核心优化：借鉴自参考代码的 YUV420 转换算法 ---
  // 这个算法能更好地处理 Android 相机的 Stride 和 PixelPadding
  static img.Image _convertYUV420(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    
    // 创建一个空白图片
    var buffer = img.Image(width: width, height: height);
    
    // YUV 分量
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int? uvPixelStride = image.planes[1].bytesPerPixel; // 关键！
    
    if (uvPixelStride == null) return buffer;

    // 遍历像素
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        // 计算 UV 索引
        final int uvIndex = uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
        
        final int index = y * width + x;
        
        // 获取 YUV 值
        // 注意：image.planes[0] 是 Y, [1] 是 U, [2] 是 V
        final yp = image.planes[0].bytes[index];
        final up = image.planes[1].bytes[uvIndex];
        final vp = image.planes[2].bytes[uvIndex];

        // YUV to RGB 公式
        // 这里的公式与参考代码一致
        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).round().clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

        // 设置像素颜色
        buffer.setPixelRgb(x, y, r, g, b);
      }
    }
    
    return buffer;
  }
}