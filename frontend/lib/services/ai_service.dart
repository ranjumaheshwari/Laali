import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/mcp_knowledge_base.dart';
import '../config/api_config.dart';

class AIService {
  // Gemini API key and endpoint
  final String _geminiKey;
  static const String _geminiURL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';

  AIService({String? apiKey}) : _geminiKey = apiKey ?? (ApiConfig.geminiKey.isNotEmpty ? ApiConfig.geminiKey : const String.fromEnvironment('GEMINI_API_KEY', defaultValue: ''));

  // ---------------- Knowledge-base search helpers ----------------

  String? _searchKnowledgeBase(String query) {
    final lowerQuery = query.toLowerCase();
    final knowledge = MCPKnowledgeBase.knowledge;

    // 1) QA pairs
    final qaPairs = knowledge['qa_pairs'] as Map<String, dynamic>?;
    if (qaPairs != null) {
      final qTokens = _tokenize(lowerQuery);
      for (final question in qaPairs.keys) {
        final qText = question.toString();
        final qLower = qText.toLowerCase();
        if (lowerQuery.contains(qLower) || qLower.contains(lowerQuery)) {
          final answer = qaPairs[question]?['answer']?.toString();
          if (answer != null && answer.isNotEmpty) return answer;
        }
        final questionTokens = _tokenize(qLower);
        if (_tokenOverlapMatches(qTokens, questionTokens)) {
          final answer = qaPairs[question]?['answer']?.toString();
          if (answer != null && answer.isNotEmpty) return answer;
        }
      }
    }

    // 2) Categories / nested content
    return _searchCategories(lowerQuery, knowledge);
  }

  String? _searchCategories(String query, Map<String, dynamic> knowledge) {
    if (knowledge['categories'] is! Map) return null;
    final categories = knowledge['categories'] as Map<String, dynamic>;

    final qTokens = _tokenize(query);

    for (final catKey in categories.keys) {
      final catData = categories[catKey];
      if (catData is! Map) continue;

      for (final subKey in catData.keys) {
        final subDataRaw = catData[subKey];
        if (subDataRaw is! Map) continue;
        final subData = Map<String, dynamic>.from(subDataRaw);

        // direct matching
        final formatted = _extractRelevantAnswer(subData, query);
        if (formatted != null) return formatted;

        // title/content/keywords token overlap
        final title = (subData['title'] ?? '').toString().toLowerCase();
        if (_tokenOverlapMatches(qTokens, _tokenize(title))) return _formatAnswer(subData);

        final content = subData['content'];
        if (content is String) {
          if (_tokenOverlapMatches(qTokens, _tokenize(content.toLowerCase()))) return _formatAnswer(subData);
        } else if (content is Map) {
          for (final k in content.keys) {
            final v = content[k]?.toString().toLowerCase() ?? '';
            if (_tokenOverlapMatches(qTokens, _tokenize(v))) return _formatAnswer(subData, specificKey: k.toString());
          }
        }

        final keywords = (subData['keywords'] is List) ? List<String>.from(subData['keywords']) : null;
        if (keywords != null) {
          final kwTokens = keywords.map((e) => e.toString().toLowerCase()).toList();
          if (_tokenOverlapMatches(qTokens, kwTokens)) return _formatAnswer(subData);
        }
      }
    }
    return null;
  }

  String? _extractRelevantAnswer(Map<String, dynamic> data, String query) {
    final title = data['title']?.toString() ?? '';
    if (title.toLowerCase().contains(query)) return _formatAnswer(data);

    final content = data['content'];
    if (content is Map) {
      for (final key in content.keys) {
        final val = content[key]?.toString() ?? '';
        if (val.toLowerCase().contains(query) || query.contains(key.toString().toLowerCase())) {
          return _formatAnswer(data, specificKey: key.toString());
        }
      }
    } else if (content is String) {
      if (content.toLowerCase().contains(query)) return _formatAnswer(data);
    }

    final keywords = (data['keywords'] is List) ? List<String>.from(data['keywords']) : null;
    if (keywords != null) {
      for (final k in keywords) {
        if (query.contains(k.toLowerCase())) return _formatAnswer(data);
      }
    }
    return null;
  }

  String _formatAnswer(Map<String, dynamic> data, {String? specificKey}) {
    final title = data['title']?.toString() ?? 'ಮಾಹಿತಿ';
    String content = '';

    if (specificKey != null && data['content'] is Map) {
      final contentMap = data['content'] as Map;
      content = contentMap[specificKey]?.toString() ?? '';
    } else if (data['content'] is Map) {
      final contentMap = data['content'] as Map;
      content = contentMap.entries.map((e) => '${e.key}: ${e.value}').join('\n');
    } else if (data['content'] is String) {
      content = data['content'];
    }

    return '$title\n\n$content';
  }

  List<String> _tokenize(String s) {
    if (s.isEmpty) return [];
    final cleaned = s.replaceAll(RegExp(r"[^\w\s\u0C80-\u0CFF]"), ' ').toLowerCase();
    final parts = cleaned.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    const stopwords = {
      'the', 'is', 'are', 'am', 'a', 'an', 'in', 'on', 'at', 'to', 'please', 'my', 'ನನ್ನ', 'ನಾನು', 'ಇಲ್ಲ', 'ಹೌದು', 'ಇದು', 'ಈ', 'ಅವರು'
    };

    final filtered = parts.where((p) => !stopwords.contains(p)).toList();
    return filtered;
  }

  bool _tokenOverlapMatches(List<String> queryTokens, List<String> targetTokens, {double threshold = 0.35}) {
    if (queryTokens.isEmpty || targetTokens.isEmpty) return false;

    final qSet = queryTokens.toSet();
    final tSet = targetTokens.toSet();
    final intersection = qSet.intersection(tSet);
    final overlap = intersection.length.toDouble();

    final score1 = overlap / (qSet.length);
    final score2 = overlap / (tSet.length);
    final score = (score1 + score2) / 2.0;

    debugPrint('AIService token overlap score: $score (q=${qSet.length}, t=${tSet.length}, overlap=${intersection.length})');

    return score >= threshold;
  }

  // ---------------- Public API ----------------

  Future<String> getResponse(String userMessage, String context) async {
    debugPrint('AI Service - User query: $userMessage');

    // 1) Try KB search
    final jsonResponse = _searchKnowledgeBase(userMessage);
    if (jsonResponse != null) {
      debugPrint('AI Service - Responding from JSON knowledge base');
      return jsonResponse;
    }

    // 2) Fallback to Gemini.
    debugPrint('AI Service - Using Gemini AI');
    return await _getGeminiAIResponse(userMessage);
  }

  // ---------------- Gemini API call ----------------

  Future<String> _getGeminiAIResponse(String userMessage) async {
    try {
      if (_geminiKey.isEmpty) {
        debugPrint('Gemini API key not provided; returning fallback');
        return _getFallbackResponse(userMessage);
      }

      final body = {
        "contents": [
          {
            "parts": [
              {"text": '''
You are a Kannada-speaking maternal and child healthcare expert.
CRITICAL INSTRUCTIONS:
- Respond ONLY in Kannada language
- Be concise, accurate, and helpful (under 150 words)
- Use simple, clear Kannada that can be easily understood when spoken
- Focus on practical, actionable advice
- If you don't know something, suggest consulting a doctor

User Question: $userMessage

Provide response in Kannada:
'''}
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.7,
          "topK": 40,
          "topP": 0.95,
          "maxOutputTokens": 300
        }
      };

      final response = await http.post(Uri.parse('$_geminiURL?key=$_geminiKey'), headers: {
        'Content-Type': 'application/json',
      }, body: jsonEncode(body));

      if (response.statusCode != 200) {
        debugPrint('Gemini API error: ${response.statusCode} - ${response.body}');
        return _getFallbackResponse(userMessage);
      }

      final data = jsonDecode(response.body);

      // Try several common shapes of Gemini-like responses for robustness
      // 1) candidates -> content -> parts -> text
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        final first = candidates[0];
        final content = first['content'];
        if (content != null) {
          final parts = content['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            final text = parts[0]['text']?.toString();
            if (text != null && text.isNotEmpty) return text;
          }
        }
      }

      // 2) result->candidates->output or result->content
      final result = data['result'];
      if (result is Map) {
        final resCands = result['candidates'] as List<dynamic>?;
        if (resCands != null && resCands.isNotEmpty) {
          final out = resCands[0]['output'] ?? resCands[0]['content'];
          if (out != null) {
            if (out is String && out.isNotEmpty) return out;
            if (out is Map) {
              final parts = out['parts'] as List<dynamic>?;
              if (parts != null && parts.isNotEmpty) {
                final t = parts[0]['text']?.toString();
                if (t != null && t.isNotEmpty) return t;
              }
            }
          }
        }
      }

      // 3) fallback: try top-level reply fields
      final reply = data['reply'] ?? data['content'] ?? data['text'];
      if (reply is String && reply.isNotEmpty) return reply;

      return _getFallbackResponse(userMessage);
    } catch (e) {
      debugPrint('Gemini API exception: $e');
      return _getFallbackResponse(userMessage);
    }
  }

  String _getFallbackResponse(String question) {
    return '''ಕ್ಷಮಿಸಿ, ನಿಮ್ಮ ಪ್ರಶ್ನೆಗೆ ಉತ್ತರವನ್ನು ಕಂಡುಹಿಡಿಯಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ: "$question"
ದಯವಿಟ್ಟು ಈ ವಿಷಯಗಳ ಬಗ್ಗೆ ಕೇಳಿ: • ಗರ್ಭಾವಸ್ಥೆಯ ಸಲಹೆಗಳು • ಶಿಶು ಆಹಾರ ಮತ್ತು ಪೋಷಣೆ • ಟೀಕೆಗಳು ಮತ್ತು ಆರೋಗ್ಯ • ಶಿಶು ಅಭಿವೃದ್ಧಿ • ತುರ್ತು ಸಂದರ್ಭಗಳು''';
  }
}

final aiService = AIService();
