import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';

/// Production-grade Gemini Vision triage service for municipal hazard analysis.
class GeminiTriageService {
  // --- Supported Live Models (with automatic failover) -----------------------
  static const List<String> _models = [
    'gemini-2.5-flash',
    'gemini-3.6-flash',
  ];

  static const double _deduplicationRadiusMeters = 30.0;

  static const List<String> _validCategories = [
    'Pothole',
    'Garbage Overflow',
    'Broken Streetlight',
    'Waterlogging',
    'Exposed Wires',
    'Fallen Tree',
    'Road Hazard',
  ];

  static const String _triagePrompt =
      'You are an expert municipal hazard triage AI. Inspect the civic hazard in this image carefully. '
      'Identify the real problem visible in the picture. '
      'Return ONLY a raw JSON object with keys: '
      '"category" (strictly one of: "Pothole", "Garbage Overflow", "Broken Streetlight", "Waterlogging", "Exposed Wires", "Fallen Tree", "Road Hazard"), '
      '"severity" (strictly one of: "Low", "Medium", "High", "Critical"), '
      '"confidence" (integer between 70 and 99), '
      '"description" (1 concise sentence describing the hazard in this photo), and '
      '"hazard_reason" (1 concise sentence explaining the public safety risk).';

  // Active Gemini API Key
  static const String _defaultApiKey =
      'AQ.Ab8RN6JGsFuPlUFPLeJUQAtzCkVeSbDtzKd0WHoVct_UUDifMw';

  // --- HTTP Client ---------------------------------------------------------
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  // --- Runtime API Key Override --------------------------------------------
  static String? _runtimeApiKey;

  static void setRuntimeApiKey(String key) {
    _runtimeApiKey = key.trim();
  }

  static String get _effectiveApiKey {
    if (_runtimeApiKey != null && _runtimeApiKey!.isNotEmpty) {
      return _runtimeApiKey!;
    }
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.isNotEmpty) {
      _runtimeApiKey = envKey;
      return envKey;
    }
    return _defaultApiKey;
  }

  static bool get isApiKeyConfigured {
    final key = _effectiveApiKey;
    return key.isNotEmpty &&
        key != 'your-gemini-api-key-here' &&
        !key.contains('dummy');
  }

  // --- Helpers -------------------------------------------------------------
  static String _cleanBase64(String raw) {
    return raw
        .replaceAll(
          RegExp(r'^data:image\/[a-z0-9\+\-\.]+;base64,', caseSensitive: false),
          '',
        )
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .replaceAll(' ', '')
        .trim();
  }

  static Map<String, dynamic> _parseGeminiJson(String rawText) {
    final cleaned = rawText
        .replaceAll(RegExp(r'```json', caseSensitive: false), '')
        .replaceAll('```', '')
        .trim();

    try {
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (_) {}

    final match = RegExp(r'\{[\s\S]*?\}').firstMatch(cleaned);
    if (match != null) {
      try {
        return jsonDecode(match.group(0)!) as Map<String, dynamic>;
      } catch (_) {}
    }

    return {};
  }

  // --- Public Triage API ---------------------------------------------------
  static Future<Map<String, dynamic>> triageImage({
    required String base64Image,
    required double latitude,
    required double longitude,
    required List<Map<String, dynamic>> existingTickets,
    String? category,
  }) async {
    final apiKey = _effectiveApiKey.trim();
    final cleanBase64 = _cleanBase64(base64Image);

    if (cleanBase64.isEmpty) {
      return _buildErrorResult(
        latitude: latitude,
        longitude: longitude,
        error: 'No image data was provided to analyze.',
      );
    }

    final payload = {
      'contents': [
        {
          'parts': [
            {'text': _triagePrompt},
            {
              'inlineData': {'mimeType': 'image/jpeg', 'data': cleanBase64},
            },
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
      },
    };

    Map<String, dynamic>? parsedResult;
    String lastErrorMessage = '';

    // Iterate through available models for guaranteed uptime
    for (final model in _models) {
      final endpoint =
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';

      try {
        final response = await _dio.post(
          endpoint,
          data: payload,
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
          ),
        );

        final dynamic resData = response.data is String
            ? jsonDecode(response.data)
            : response.data;

        final rawText = resData?['candidates']?[0]?['content']?['parts']?[0]
                ?['text'] as String? ??
            '';

        if (rawText.isNotEmpty) {
          final parsed = _parseGeminiJson(rawText);
          if (parsed.isNotEmpty && parsed.containsKey('category')) {
            parsedResult = parsed;
            break; // Successfully triaged
          }
        }
      } on DioException catch (e) {
        final errBody = e.response?.data;
        lastErrorMessage = errBody is Map
            ? (errBody['error']?['message'] ?? e.message)
            : (e.message ?? 'HTTP ${e.response?.statusCode}');
      } catch (e) {
        lastErrorMessage = e.toString();
      }
    }

    // If API analysis failed, return direct error state rather than a silent random mock
    if (parsedResult == null) {
      return _buildErrorResult(
        latitude: latitude,
        longitude: longitude,
        error: 'AI Triage Error: $lastErrorMessage',
      );
    }

    String detectedCategory =
        parsedResult['category'] as String? ?? 'Road Hazard';
    if (!_validCategories.contains(detectedCategory)) {
      detectedCategory = _inferCategoryFromText(
        '${parsedResult['description'] ?? ''} ${parsedResult['hazard_reason'] ?? ''} $detectedCategory',
      );
    }

    final String severity = _normalizeSeverity(
      parsedResult['severity'] as String? ?? 'Medium',
    );

    final confidenceRaw = parsedResult['confidence'];
    double confidence = 0.88;
    if (confidenceRaw is int) {
      confidence = confidenceRaw / 100.0;
    } else if (confidenceRaw is double) {
      confidence =
          confidenceRaw > 1.0 ? confidenceRaw / 100.0 : confidenceRaw;
    }

    final String description = parsedResult['description'] as String? ??
        'Civic hazard detected in uploaded image.';
    final String hazardReason = parsedResult['hazard_reason'] as String? ??
        'This hazard requires municipal attention.';

    final duplicate = _findDuplicate(
      latitude,
      longitude,
      detectedCategory,
      existingTickets,
    );

    return {
      'category': detectedCategory,
      'severity': severity,
      'reason': description,
      'description': description,
      'hazard_reason': hazardReason,
      'confidence': confidence,
      'latitude': latitude,
      'longitude': longitude,
      'isDuplicate': duplicate != null,
      'duplicateTicketId': duplicate?['id'],
      'upvotesAwarded': duplicate != null ? 5 : 0,
      'apiKeyMissing': false,
      'error': null,
    };
  }

  // --- Public Repair Verification API --------------------------------------
  static Future<Map<String, dynamic>> verifyRepair({
    required String beforeImageBase64,
    required String afterImageBase64,
    required String category,
  }) async {
    final apiKey = _effectiveApiKey.trim();
    final cleanBefore = _cleanBase64(beforeImageBase64);
    final cleanAfter = _cleanBase64(afterImageBase64);

    final payload = {
      'contents': [
        {
          'parts': [
            {
              'text':
                  'Compare these two images of a civic repair job for "$category".\n'
                  'Image 1 (BEFORE): Shows the original hazard.\n'
                  'Image 2 (AFTER): Shows the repair attempt.\n\n'
                  'Has the repair been successfully completed? '
                  'Return ONLY a raw JSON object: '
                  '{"verified": true or false, "confidence": integer 0-100, "summary": "one sentence verdict", "details": "what you observed in both images"}',
            },
            {
              'inlineData': {'mimeType': 'image/jpeg', 'data': cleanBefore},
            },
            {
              'inlineData': {'mimeType': 'image/jpeg', 'data': cleanAfter},
            },
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
      },
    };

    for (final model in _models) {
      final endpoint =
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';

      try {
        final response = await _dio.post(
          endpoint,
          data: payload,
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
          ),
        );

        final dynamic resData = response.data is String
            ? jsonDecode(response.data)
            : response.data;

        final rawText = resData?['candidates']?[0]?['content']?['parts']?[0]
                ?['text'] as String? ??
            '';

        final parsed = _parseGeminiJson(rawText);
        if (parsed.isNotEmpty) {
          final confidenceRaw = parsed['confidence'];
          double confidenceDouble = 0.85;
          if (confidenceRaw is int) {
            confidenceDouble = confidenceRaw / 100.0;
          } else if (confidenceRaw is double) {
            confidenceDouble = confidenceRaw > 1.0
                ? confidenceRaw / 100.0
                : confidenceRaw;
          }

          return {
            'verified': parsed['verified'] ?? false,
            'confidence': confidenceDouble,
            'summary': parsed['summary'] ?? 'Verification complete.',
            'details': parsed['details'] ?? 'Assessed via Gemini Vision audit.',
          };
        }
      } catch (_) {}
    }

    return {
      'verified': false,
      'confidence': 0.0,
      'summary': 'Verification failed',
      'details': 'Could not complete AI verification.',
    };
  }

  // --- Private Utilities ---------------------------------------------------
  static Map<String, dynamic> _buildErrorResult({
    required double latitude,
    required double longitude,
    required String error,
  }) {
    return {
      'category': 'Road Hazard',
      'severity': 'Medium',
      'reason': error,
      'description': error,
      'hazard_reason': 'Could not complete AI vision triage.',
      'confidence': 0.0,
      'latitude': latitude,
      'longitude': longitude,
      'isDuplicate': false,
      'duplicateTicketId': null,
      'upvotesAwarded': 0,
      'apiKeyMissing': !isApiKeyConfigured,
      'error': error,
    };
  }

  static String _normalizeSeverity(String raw) {
    switch (raw.toLowerCase()) {
      case 'critical':
        return 'Critical';
      case 'high':
        return 'High';
      case 'medium':
      case 'moderate':
        return 'Medium';
      case 'low':
        return 'Low';
      default:
        return 'Medium';
    }
  }

  static String _inferCategoryFromText(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('pothole') ||
        lower.contains('road crack') ||
        lower.contains('road damage')) {
      return 'Pothole';
    }
    if (lower.contains('streetlight') ||
        lower.contains('street light') ||
        lower.contains('lamp') ||
        lower.contains('bulb')) {
      return 'Broken Streetlight';
    }
    if (lower.contains('waterlog') ||
        lower.contains('flood') ||
        lower.contains('standing water') ||
        lower.contains('drainage')) {
      return 'Waterlogging';
    }
    if (lower.contains('wire') ||
        lower.contains('electric') ||
        lower.contains('cable') ||
        lower.contains('exposed')) {
      return 'Exposed Wires';
    }
    if (lower.contains('garbage') ||
        lower.contains('trash') ||
        lower.contains('waste') ||
        lower.contains('litter') ||
        lower.contains('bin')) {
      return 'Garbage Overflow';
    }
    if (lower.contains('tree') || lower.contains('fallen')) {
      return 'Fallen Tree';
    }
    return 'Road Hazard';
  }

  static Map<String, dynamic>? _findDuplicate(
    double lat,
    double lng,
    String category,
    List<Map<String, dynamic>> tickets,
  ) {
    for (final ticket in tickets) {
      final tLat = (ticket['latitude'] as num?)?.toDouble();
      final tLng = (ticket['longitude'] as num?)?.toDouble();
      if (tLat == null || tLng == null) continue;

      if (_haversineDistance(lat, lng, tLat, tLng) >
          _deduplicationRadiusMeters) {
        continue;
      }

      if ((ticket['category'] as String? ?? '').toLowerCase().trim() ==
          category.toLowerCase().trim()) {
        return ticket;
      }
    }
    return null;
  }

  static double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * pi / 180;
}