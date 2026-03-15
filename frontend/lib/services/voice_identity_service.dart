import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VoiceIdentityService {
  static const String _userProfileKey = 'user_profile_data';
  static const String _voicePatternsKey = 'user_voice_patterns';

  /// Create voice identity for ANY name
  Future<void> createVoiceIdentity(String userName) async {
    final prefs = await SharedPreferences.getInstance();

    // Store basic profile
    await prefs.setString(_userProfileKey, jsonEncode({
      'name': userName,
      'createdAt': DateTime.now().toIso8601String(),
      'voiceSampleCount': 1,
    }));

    // Store voice patterns for this specific name
    final voicePatterns = await _getVoicePatterns();
    voicePatterns[userName.toLowerCase()] = {
      'recognizedVariations': [userName], // Start with the original name
      'lastRecognized': DateTime.now().toIso8601String(),
      'confidence': 0.8,
    };

    await prefs.setString(_voicePatternsKey, jsonEncode(voicePatterns));
    debugPrint('Voice identity created for: $userName');
  }

  /// Identify user from ANY spoken name
  Future<String?> identifyUserFromVoice(String spokenName) async {
    final prefs = await SharedPreferences.getInstance();
    final profileData = prefs.getString(_userProfileKey);

    if (profileData == null) return null; // No user registered

    final profile = jsonDecode(profileData);
    final storedName = profile['name'];
    final voicePatterns = await _getVoicePatterns();

    // Get confidence for this spoken name
    final confidence = _calculateMatchConfidence(spokenName, storedName, voicePatterns);

    if (confidence > 0.6) { // 60% confidence threshold
      // Learn this variation for future
      await _learnNameVariation(storedName, spokenName);
      return storedName;
    }

    return null;
  }

  /// Calculate match confidence for ANY name
  double _calculateMatchConfidence(String spokenName, String storedName, Map<String, dynamic> voicePatterns) {
    final spokenLower = spokenName.toLowerCase().trim();
    final storedLower = storedName.toLowerCase().trim();

    // 1. Exact match
    if (spokenLower == storedLower) return 0.95;

    // 2. Check learned variations
    final variations = voicePatterns[storedLower]?['recognizedVariations'] ?? [];
    for (final variation in variations) {
      if (spokenLower == variation.toLowerCase()) return 0.9;
    }

    // 3. Phonetic similarity (works for any Kannada/English name)
    if (_arePhoneticallySimilar(spokenLower, storedLower)) return 0.8;

    // 4. Partial match
    if (spokenLower.contains(storedLower) || storedLower.contains(spokenLower)) return 0.7;

    // 5. Length-based similarity
    if (_areLengthSimilar(spokenLower, storedLower)) return 0.6;

    return 0.3;
  }

  /// Phonetic similarity for ANY names
  bool _arePhoneticallySimilar(String name1, String name2) {
    // Common phonetic variations in Kannada speech recognition
    final phoneticGroups = [
      ['ಾ', 'ಾ'], ['ಿ', 'ೀ'], ['ು', 'ೂ'], ['ೆ', 'ೇ'], ['ೊ', 'ೋ'],
      ['ಕ', 'ಖ'], ['ಗ', 'ಘ'], ['ಚ', 'ಛ'], ['ಜ', 'ಝ'], ['ಟ', 'ಠ'],
      ['ಡ', 'ಢ'], ['ತ', 'ಥ'], ['ದ', 'ಧ'], ['ಪ', 'ಫ'], ['ಬ', 'ಭ'],
      ['ಶ', 'ಷ'], ['ಸ', 'ಶ'], ['ನ', 'ಣ'], ['ಳ', 'ಲ'],
    ];

    var similarityScore = 0;
    final minLength = name1.length < name2.length ? name1.length : name2.length;

    for (int i = 0; i < minLength; i++) {
      final char1 = name1[i];
      final char2 = name2[i];

      if (char1 == char2) {
        similarityScore += 2;
      } else {
        // Check phonetic groups
        for (final group in phoneticGroups) {
          if (group.contains(char1) && group.contains(char2)) {
            similarityScore += 1;
            break;
          }
        }
      }
    }

    final maxPossibleScore = minLength * 2;
    return (similarityScore / (maxPossibleScore == 0 ? 1 : maxPossibleScore)) > 0.7;
  }

  bool _areLengthSimilar(String name1, String name2) {
    final length1 = name1.length;
    final length2 = name2.length;
    final difference = (length1 - length2).abs();
    return difference <= 2;
  }

  /// Learn new name variations dynamically
  Future<void> _learnNameVariation(String storedName, String newVariation) async {
    final voicePatterns = await _getVoicePatterns();
    final storedLower = storedName.toLowerCase();

    if (voicePatterns[storedLower] != null) {
      final variations = List<String>.from(voicePatterns[storedLower]!['recognizedVariations'] ?? []);
      if (!variations.contains(newVariation)) {
        variations.add(newVariation);
        voicePatterns[storedLower]!['recognizedVariations'] = variations;
        voicePatterns[storedLower]!['confidence'] = 0.9;
        voicePatterns[storedLower]!['lastRecognized'] = DateTime.now().toIso8601String();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_voicePatternsKey, jsonEncode(voicePatterns));

        debugPrint('Learned new variation: $newVariation for $storedName');
      }
    }
  }

  Future<Map<String, dynamic>> _getVoicePatterns() async {
    final prefs = await SharedPreferences.getInstance();
    final patternsJson = prefs.getString(_voicePatternsKey);
    return patternsJson != null ? Map<String, dynamic>.from(jsonDecode(patternsJson)) : {};
  }

  /// Get stored user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profileJson = prefs.getString(_userProfileKey);

    if (profileJson == null) return null;

    final profile = jsonDecode(profileJson);
    final userMode = prefs.getString('userMode');
    final lmpDate = prefs.getString('lmpDate');

    return {
      'name': profile['name'],
      'mode': userMode,
      'lmpDate': lmpDate,
      'createdAt': profile['createdAt'],
      'voiceSampleCount': profile['voiceSampleCount'] ?? 1,
    };
  }

  /// Check if user exists
  Future<bool> hasExistingUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userProfileKey) != null;
  }

  /// Clear user data (for testing/new user)
  Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userProfileKey);
    await prefs.remove(_voicePatternsKey);
    await prefs.remove('userMode');
    await prefs.remove('username');
    await prefs.remove('lmpDate');
  }
}

final voiceIdentityService = VoiceIdentityService();