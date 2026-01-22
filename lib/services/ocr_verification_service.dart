// lib/services/ocr_verification_service.dart
// OCR 文档验证服务 - 用于验证业主上传的 Title Deed 文档

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

/// OCR 验证结果模型
class OcrVerificationResult {
  final String extractedText;         // OCR 提取的原始文字
  final int confidenceScore;          // 总可信度分数 (0-100)
  final bool nameMatched;             // 姓名是否匹配
  final int nameMatchScore;           // 姓名匹配分数 (0-100)
  final bool unitMatched;             // 单位号是否匹配
  final int unitMatchScore;           // 单位号匹配分数 (0-100)
  final bool documentTypeDetected;    // 是否检测到房产文件类型
  final List<String> detectedKeywords; // 检测到的关键词
  final String recommendation;        // 推荐操作: auto_approve / manual_review / needs_attention

  OcrVerificationResult({
    required this.extractedText,
    required this.confidenceScore,
    required this.nameMatched,
    required this.nameMatchScore,
    required this.unitMatched,
    required this.unitMatchScore,
    required this.documentTypeDetected,
    required this.detectedKeywords,
    required this.recommendation,
  });

  /// 转换为 Map 用于存储到 Firestore
  Map<String, dynamic> toMap() {
    return {
      'extractedText': extractedText,
      'confidenceScore': confidenceScore,
      'nameMatched': nameMatched,
      'nameMatchScore': nameMatchScore,
      'unitMatched': unitMatched,
      'unitMatchScore': unitMatchScore,
      'documentTypeDetected': documentTypeDetected,
      'detectedKeywords': detectedKeywords,
      'recommendation': recommendation,
    };
  }

  /// 从 Firestore Map 创建实例
  factory OcrVerificationResult.fromMap(Map<String, dynamic> map) {
    return OcrVerificationResult(
      extractedText: map['extractedText'] ?? '',
      confidenceScore: map['confidenceScore'] ?? 0,
      nameMatched: map['nameMatched'] ?? false,
      nameMatchScore: map['nameMatchScore'] ?? 0,
      unitMatched: map['unitMatched'] ?? false,
      unitMatchScore: map['unitMatchScore'] ?? 0,
      documentTypeDetected: map['documentTypeDetected'] ?? false,
      detectedKeywords: List<String>.from(map['detectedKeywords'] ?? []),
      recommendation: map['recommendation'] ?? 'needs_attention',
    );
  }
}

/// OCR 验证服务类
class OcrVerificationService {
  // ML Kit 文字识别器
  final TextRecognizer _textRecognizer = TextRecognizer();

  // 马来西亚房产文件关键词列表
  static const List<String> _documentKeywords = [
    // 英文关键词
    'title deed',
    'strata title',
    'land title',
    'grant',
    'lease',
    'freehold',
    'leasehold',
    'lot number',
    'parcel',
    'unit no',
    'master title',
    'individual title',
    'geran',
    // 马来文关键词
    'hakmilik',
    'petak',
    'pajakan',
    'geran mukim',
    'hak milik strata',
    // 常见文档标识
    'pejabat tanah',
    'land office',
    'registry',
    'deed of assignment',
    'sale and purchase',
  ];

  /// 从 Base64 图片提取文字
  /// [base64Image] - Base64 编码的图片数据
  Future<String> extractTextFromBase64(String base64Image) async {
    try {
      // 解码 Base64 为字节
      final Uint8List bytes = base64Decode(base64Image);

      // 创建临时文件
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/ocr_temp_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(bytes);

      // 使用 ML Kit 识别文字
      final inputImage = InputImage.fromFile(tempFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      // 删除临时文件
      await tempFile.delete();

      return recognizedText.text;
    } catch (e) {
      // OCR 提取文字失败，返回空字符串
      return '';
    }
  }

  /// 验证文档并计算可信度
  /// [base64Image] - Base64 编码的图片
  /// [ownerName] - 业主填写的姓名
  /// [unitNumber] - 业主填写的单位号
  Future<OcrVerificationResult> verifyDocument({
    required String base64Image,
    required String ownerName,
    required String unitNumber,
  }) async {
    // 1. 提取文字
    final extractedText = await extractTextFromBase64(base64Image);

    if (extractedText.isEmpty) {
      // OCR 失败，返回低可信度结果
      return OcrVerificationResult(
        extractedText: '',
        confidenceScore: 0,
        nameMatched: false,
        nameMatchScore: 0,
        unitMatched: false,
        unitMatchScore: 0,
        documentTypeDetected: false,
        detectedKeywords: [],
        recommendation: 'needs_attention',
      );
    }

    // 2. 检查姓名匹配
    final nameResult = _matchName(extractedText, ownerName);

    // 3. 检查单位号匹配
    final unitResult = _matchUnit(extractedText, unitNumber);

    // 4. 检测文档类型
    final docTypeResult = _detectDocumentType(extractedText);

    // 5. 计算总可信度分数
    // 权重: 姓名 40%, 单位号 40%, 文档类型 20%
    final totalScore = (nameResult['score'] as int) * 0.4 +
        (unitResult['score'] as int) * 0.4 +
        (docTypeResult['score'] as int) * 0.2;

    final confidenceScore = totalScore.round();

    // 6. 确定推荐操作
    String recommendation;
    if (confidenceScore >= 80) {
      recommendation = 'auto_approve';  // 高可信度，建议自动通过
    } else if (confidenceScore >= 60) {
      recommendation = 'manual_review'; // 中可信度，需要人工审核
    } else {
      recommendation = 'needs_attention'; // 低可信度，需要重点审核
    }

    return OcrVerificationResult(
      extractedText: extractedText,
      confidenceScore: confidenceScore,
      nameMatched: nameResult['matched'] as bool,
      nameMatchScore: nameResult['score'] as int,
      unitMatched: unitResult['matched'] as bool,
      unitMatchScore: unitResult['score'] as int,
      documentTypeDetected: docTypeResult['detected'] as bool,
      detectedKeywords: docTypeResult['keywords'] as List<String>,
      recommendation: recommendation,
    );
  }

  /// 匹配姓名
  /// 返回 {matched: bool, score: int}
  Map<String, dynamic> _matchName(String text, String name) {
    if (name.isEmpty) {
      return {'matched': false, 'score': 0};
    }

    // 标准化处理
    final normalizedText = _normalizeText(text);
    final normalizedName = _normalizeText(name);

    // 1. 完全匹配
    if (normalizedText.contains(normalizedName)) {
      return {'matched': true, 'score': 100};
    }

    // 2. 分词匹配 - 检查名字的每个部分是否都出现
    final nameParts = normalizedName.split(RegExp(r'\s+'));
    int matchedParts = 0;
    for (final part in nameParts) {
      if (part.length >= 2 && normalizedText.contains(part)) {
        matchedParts++;
      }
    }

    if (nameParts.isNotEmpty) {
      final partMatchRatio = matchedParts / nameParts.length;
      if (partMatchRatio >= 0.8) {
        return {'matched': true, 'score': 80};
      } else if (partMatchRatio >= 0.5) {
        return {'matched': true, 'score': 60};
      } else if (matchedParts > 0) {
        return {'matched': false, 'score': 30};
      }
    }

    // 3. 模糊匹配 - 使用相似度算法
    final similarity = _calculateSimilarity(normalizedName, normalizedText);
    if (similarity >= 0.7) {
      return {'matched': true, 'score': 50};
    }

    return {'matched': false, 'score': 0};
  }

  /// 匹配单位号
  /// 返回 {matched: bool, score: int}
  Map<String, dynamic> _matchUnit(String text, String unit) {
    if (unit.isEmpty) {
      return {'matched': false, 'score': 0};
    }

    // 标准化处理
    final normalizedText = _normalizeText(text);
    final normalizedUnit = _normalizeText(unit);

    // 1. 完全匹配
    if (normalizedText.contains(normalizedUnit)) {
      return {'matched': true, 'score': 100};
    }

    // 2. 去除分隔符后匹配 (如 A-12-05 -> a1205)
    final cleanUnit = normalizedUnit.replaceAll(RegExp(r'[-_\s./]'), '');
    final cleanText = normalizedText.replaceAll(RegExp(r'[-_\s./]'), '');

    if (cleanText.contains(cleanUnit)) {
      return {'matched': true, 'score': 90};
    }

    // 3. 提取单位号的数字部分进行匹配
    final unitNumbers = RegExp(r'\d+').allMatches(normalizedUnit).map((m) => m.group(0)!).toList();
    if (unitNumbers.isNotEmpty) {
      int matchedNumbers = 0;
      for (final num in unitNumbers) {
        if (normalizedText.contains(num)) {
          matchedNumbers++;
        }
      }
      final matchRatio = matchedNumbers / unitNumbers.length;
      if (matchRatio >= 0.8) {
        return {'matched': true, 'score': 70};
      } else if (matchRatio >= 0.5) {
        return {'matched': false, 'score': 40};
      }
    }

    return {'matched': false, 'score': 0};
  }

  /// 检测文档类型
  /// 返回 {detected: bool, score: int, keywords: List<String>}
  Map<String, dynamic> _detectDocumentType(String text) {
    final normalizedText = _normalizeText(text);
    final List<String> foundKeywords = [];

    for (final keyword in _documentKeywords) {
      if (normalizedText.contains(keyword.toLowerCase())) {
        foundKeywords.add(keyword);
      }
    }

    if (foundKeywords.length >= 3) {
      return {'detected': true, 'score': 100, 'keywords': foundKeywords};
    } else if (foundKeywords.length >= 2) {
      return {'detected': true, 'score': 80, 'keywords': foundKeywords};
    } else if (foundKeywords.length == 1) {
      return {'detected': true, 'score': 50, 'keywords': foundKeywords};
    }

    return {'detected': false, 'score': 0, 'keywords': <String>[]};
  }

  /// 标准化文本 - 转小写，移除多余空格
  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// 计算两个字符串的相似度 (简化的 Levenshtein 距离)
  /// 返回 0.0 - 1.0 之间的相似度
  double _calculateSimilarity(String s1, String s2) {
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    if (s1 == s2) return 1.0;

    // 检查 s1 是否是 s2 的子串
    if (s2.contains(s1)) return 0.9;

    // 简化版: 计算公共字符比例
    final set1 = s1.split('').toSet();
    final set2 = s2.split('').toSet();
    final intersection = set1.intersection(set2);
    final union = set1.union(set2);

    return intersection.length / union.length;
  }

  /// 释放资源
  void dispose() {
    _textRecognizer.close();
  }
}
