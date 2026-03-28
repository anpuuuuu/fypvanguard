// lib/services/ocr_verification_service.dart
// OCR document verification service for owner-uploaded title deed documents.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

/// Model for OCR verification results.
class OcrVerificationResult {
  final String extractedText; // Raw text from OCR
  final int confidenceScore; // Overall confidence score (0-100)
  final bool nameMatched; // Whether the name matched
  final int nameMatchScore; // Name match score (0-100)
  final bool unitMatched; // Whether the unit number matched
  final int unitMatchScore; // Unit match score (0-100)
  final bool documentTypeDetected; // Whether a property document type was detected
  final List<String> detectedKeywords; // Keywords found in the document
  final String recommendation; // Suggested action: auto_approve / manual_review / needs_attention

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

  /// Serializes to a Map for Firestore.
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

  /// Builds an instance from a Firestore Map.
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

/// Service that runs OCR and scoring for title deed verification.
class OcrVerificationService {
  // ML Kit text recognizer
  final TextRecognizer _textRecognizer = TextRecognizer();

  // Keywords associated with Malaysian property documents
  static const List<String> _documentKeywords = [
    // English keywords
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
    // Malay keywords
    'hakmilik',
    'petak',
    'pajakan',
    'geran mukim',
    'hak milik strata',
    // Common document markers
    'pejabat tanah',
    'land office',
    'registry',
    'deed of assignment',
    'sale and purchase',
  ];

  /// Extracts text from a Base64-encoded image.
  /// [base64Image] - Base64-encoded image bytes.
  Future<String> extractTextFromBase64(String base64Image) async {
    try {
      // Decode Base64 to raw bytes
      final Uint8List bytes = base64Decode(base64Image);

      // Write to a temporary file for ML Kit
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/ocr_temp_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(bytes);

      // Run ML Kit text recognition
      final inputImage = InputImage.fromFile(tempFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      // Remove temporary file
      await tempFile.delete();

      return recognizedText.text;
    } catch (e) {
      // OCR failed; return empty string
      return '';
    }
  }

  /// Verifies the document and computes a confidence score.
  /// [base64Image] - Base64-encoded image.
  /// [ownerName] - Owner name as entered in the app.
  /// [unitNumber] - Unit number as entered in the app.
  Future<OcrVerificationResult> verifyDocument({
    required String base64Image,
    required String ownerName,
    required String unitNumber,
  }) async {
    // 1. Extract text
    final extractedText = await extractTextFromBase64(base64Image);

    if (extractedText.isEmpty) {
      // OCR produced no text; return a low-confidence result
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

    // 2. Name match
    final nameResult = _matchName(extractedText, ownerName);

    // 3. Unit number match
    final unitResult = _matchUnit(extractedText, unitNumber);

    // 4. Document type detection
    final docTypeResult = _detectDocumentType(extractedText);

    // 5. Weighted overall score: name 40%, unit 40%, document type 20%
    final totalScore = (nameResult['score'] as int) * 0.4 +
        (unitResult['score'] as int) * 0.4 +
        (docTypeResult['score'] as int) * 0.2;

    final confidenceScore = totalScore.round();

    // 6. Map score to recommendation
    String recommendation;
    if (confidenceScore >= 80) {
      recommendation = 'auto_approve'; // High confidence
    } else if (confidenceScore >= 60) {
      recommendation = 'manual_review'; // Medium confidence
    } else {
      recommendation = 'needs_attention'; // Low confidence
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

  /// Matches owner name against OCR text.
  /// Returns `{matched: bool, score: int}`.
  Map<String, dynamic> _matchName(String text, String name) {
    if (name.isEmpty) {
      return {'matched': false, 'score': 0};
    }

    // Normalize whitespace and case
    final normalizedText = _normalizeText(text);
    final normalizedName = _normalizeText(name);

    // 1. Substring match
    if (normalizedText.contains(normalizedName)) {
      return {'matched': true, 'score': 100};
    }

    // 2. Token match: each name part should appear in the text
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

    // 3. Fuzzy match via similarity
    final similarity = _calculateSimilarity(normalizedName, normalizedText);
    if (similarity >= 0.7) {
      return {'matched': true, 'score': 50};
    }

    return {'matched': false, 'score': 0};
  }

  /// Matches unit number against OCR text.
  /// Returns `{matched: bool, score: int}`.
  Map<String, dynamic> _matchUnit(String text, String unit) {
    if (unit.isEmpty) {
      return {'matched': false, 'score': 0};
    }

    // Normalize whitespace and case
    final normalizedText = _normalizeText(text);
    final normalizedUnit = _normalizeText(unit);

    // 1. Substring match
    if (normalizedText.contains(normalizedUnit)) {
      return {'matched': true, 'score': 100};
    }

    // 2. Match after stripping separators (e.g. A-12-05 -> a1205)
    final cleanUnit = normalizedUnit.replaceAll(RegExp(r'[-_\s./]'), '');
    final cleanText = normalizedText.replaceAll(RegExp(r'[-_\s./]'), '');

    if (cleanText.contains(cleanUnit)) {
      return {'matched': true, 'score': 90};
    }

    // 3. Compare digit runs from the unit string
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

  /// Detects property-related document type from keywords.
  /// Returns `{detected: bool, score: int, keywords: List<String>}`.
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

  /// Lowercases and collapses whitespace.
  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Simple similarity in [0.0, 1.0] using character-set overlap.
  double _calculateSimilarity(String s1, String s2) {
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    if (s1 == s2) return 1.0;

    // Treat substring presence as high similarity
    if (s2.contains(s1)) return 0.9;

    // Ratio of shared distinct characters
    final set1 = s1.split('').toSet();
    final set2 = s2.split('').toSet();
    final intersection = set1.intersection(set2);
    final union = set1.union(set2);

    return intersection.length / union.length;
  }

  /// Releases ML Kit resources.
  void dispose() {
    _textRecognizer.close();
  }
}
