import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mcp/services/audio_player_service.dart' show audioService;
import 'package:shared_preferences/shared_preferences.dart';
import 'services/tts_service.dart';
import 'services/speech_service.dart';
import 'services/firebase_service.dart';
import 'services/video_search_service.dart'; // ADD THIS
import 'widgets/video_search_widget.dart'; // ADD THIS
import 'data/video_record.dart'; // ADD THIS
import 'welcome_page.dart';

class VoiceInterfacePage extends StatefulWidget {
  const VoiceInterfacePage({super.key});

  @override
  State<VoiceInterfacePage> createState() => _VoiceInterfacePageState();
}

class _VoiceInterfacePageState extends State<VoiceInterfacePage> {
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> messages = [];
  bool isRecording = false;
  bool isPlaying = false;
  bool isLoadingAI = false;
  bool isSpeaking = false;
  String? userMode;
  String? username;
  String? _currentlyPlayingMessageId;

  // ADD VIDEO SEARCH VARIABLES
  bool _showVideoSearch = false;
  final VideoSearchService _videoSearchService = VideoSearchService();
  List<VideoRecord> _videoResults = [];

  // Recording state
  Duration _recordingDuration = Duration.zero;
  late Timer _recordingTimer;
  bool _showCancelOption = false;

  final FirebaseService _firebaseService = FirebaseService();

  static const String n8nWebhookUrl = 'https://boundless-unprettily-voncile.ngrok-free.dev/webhook-test/user-message';
  static const Duration n8nResponseTimeout = Duration(seconds: 300);

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadUserData();
    _addWelcomeMessage();
    _initializeVideoSearch(); // ADD THIS

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _speak('ನಮಸ್ಕಾರ! ಮೈಕ್ರೊಫೋನ್ ಟ್ಯಾಪ್ ಮಾಡಿ ಮತ್ತು ನಿಮ್ಮ ಪ್ರಶ್ನೆಗಳನ್ನು ಕೇಳಿ.');
    });
  }

  // ADD VIDEO SEARCH INITIALIZATION
  Future<void> _initializeVideoSearch() async {
    try {
      await _videoSearchService.initialize();
      debugPrint('✅ Video search initialized in voice interface');
    } catch (e) {
      debugPrint('❌ Video search init failed: $e');
    }
  }

  // SAFE NAVIGATION METHODS
  void _navigateToWelcome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const WelcomePage()),
          (route) => false,
    );
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userMode = prefs.getString('userMode');
      username = prefs.getString('username') ?? 'User';
    });

    // Load chat history
    await _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    try {
      final notes = await _firebaseService.getRecentVisitNotes(limit: 50);
      final List<ChatMessage> loadedMessages = [];

      for (final note in notes) {
        final transcript = (note['transcript'] ?? '').toString();
        final timestamp = (note['created_at'] as Timestamp).toDate();

        if (transcript.isNotEmpty) {
          loadedMessages.add(ChatMessage(
            id: 'user_${timestamp.millisecondsSinceEpoch}',
            content: transcript,
            timestamp: timestamp,
            isUser: true,
            audioUrl: null,
          ));
        }
      }

      // Sort by timestamp and add to messages
      loadedMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      setState(() {
        messages.addAll(loadedMessages);
      });
    } catch (e) {
      debugPrint('Error loading chat history: $e');
    }
  }

  void _addWelcomeMessage() {
    final welcomeMsg = ChatMessage(
      id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
      content: 'ನಮಸ್ಕಾರ! ನಾನು ನಿಮ್ಮ ಧ್ವನಿ ಸಹಾಯಕ. ನಿಮ್ಮ ಸಮಸ್ಯೆಗಳನ್ನು ಹೇಳಿ ಅಥವಾ ಪ್ರಶ್ನೆ ಕೇಳಿ. "ವೀಡಿಯೊಗಳು ಹುಡುಕಿ" ಎಂದು ಹೇಳಿ ವೀಡಿಯೊಗಳಿಗಾಗಿ ಹುಡುಕಬಹುದು.',
      timestamp: DateTime.now(),
      isUser: false,
      audioUrl: null,
    );
    setState(() => messages.add(welcomeMsg));
  }

  Future<void> _initTts() async {
    await ttsService.setLanguage('kn-IN');
    await ttsService.setSpeechRate(0.4);
    await ttsService.setPitch(1.0);
  }

  Future<void> _speak(String text) async {
    try {
      setState(() => isSpeaking = true);
      await ttsService.speak(text);
    } catch (e) {
      debugPrint('TTS speak error: $e');
    } finally {
      if (mounted) {
        setState(() => isSpeaking = false);
      }
    }
  }

  // ADD VIDEO SEARCH METHOD
  Future<void> _handleVideoSearch(String query) async {
    if (!_videoSearchService.isInitialized) {
      await _speak('ವೀಡಿಯೊ ಹುಡುಕಾಟ ಸೇವೆ ಲಭ್ಯವಿಲ್ಲ.');
      return;
    }

    setState(() {
      isLoadingAI = true;
      _showVideoSearch = true;
    });

    try {
      final results = await _videoSearchService.searchSimilarVideos(
        query: query,
        topN: 5,
      );

      setState(() {
        _videoResults = results;
      });

      if (results.isEmpty) {
        await _speak('"$query" ಗಾಗಿ ಯಾವುದೇ ವೀಡಿಯೊಗಳು ಕಂಡುಬಂದಿಲ್ಲ.');
      } else {
        await _speak('ನಾನು "$query" ಗಾಗಿ ${results.length} ವೀಡಿಯೊಗಳನ್ನು ಕಂಡುಹಿಡಿದಿದ್ದೇನೆ.');
      }
    } catch (e) {
      await _speak('ವೀಡಿಯೊ ಹುಡುಕಾಟದಲ್ಲಿ ಸಮಸ್ಯೆಯಾಗಿದೆ.');
      debugPrint('Video search error: $e');
    } finally {
      setState(() {
        isLoadingAI = false;
      });
    }
  }

  // MODIFIED RECORDING METHOD TO DETECT VIDEO SEARCH QUERIES
  void _startRecording() async {
    final ok = await speechService.initialize();
    if (!ok) {
      await _speak('ಕ್ಷಮಿಸಿ, ಮೈಕ್ರೊಫೋನ್ ಲಭ್ಯವಿಲ್ಲ.');
      return;
    }

    setState(() {
      isRecording = true;
      _recordingDuration = Duration.zero;
      _showCancelOption = false;
    });

    // Start recording timer
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordingDuration += const Duration(seconds: 1);
        });
      }
    });

    // Show cancel option after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && isRecording) {
        setState(() => _showCancelOption = true);
      }
    });

    try {
      await speechService.startListeningWithRetry((text, isFinal) {
        if (isFinal && text.isNotEmpty) {
          _stopRecording(text);
        }
      }, localeId: 'kn-IN', retries: 1, attemptTimeout: const Duration(seconds: 30));
    } catch (e) {
      _stopRecording('');
    }
  }

  void _stopRecording(String transcript) {
    _recordingTimer.cancel();

    if (mounted) {
      setState(() {
        isRecording = false;
        _showCancelOption = false;
      });
    }

    if (transcript.isNotEmpty) {
      _showRecordingPreview(transcript);
    }
  }

  void _cancelRecording() {
    _recordingTimer.cancel();
    speechService.stop();

    if (mounted) {
      setState(() {
        isRecording = false;
        _showCancelOption = false;
      });
    }

    _speak('ರೆಕಾರ್ಡಿಂಗ್ ರದ್ದುಗೊಳಿಸಲಾಗಿದೆ.');
  }

  void _showRecordingPreview(String transcript) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ನಿಮ್ಮ ಸಂದೇಶ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '"$transcript"',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Big Send Button
                SizedBox(
                  width: 120,
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send, size: 24),
                    label: const Text('ಕಳುಹಿಸಿ', style: TextStyle(fontSize: 16)),
                    onPressed: () {
                      Navigator.pop(context);
                      _processUserMessage(transcript); // CHANGED THIS
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00796B),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                // Big Re-record Button
                SizedBox(
                  width: 120,
                  height: 50,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.replay, size: 24),
                    label: const Text('ಮರು-ರೆಕಾರ್ಡ್', style: TextStyle(fontSize: 14)),
                    onPressed: () {
                      Navigator.pop(context);
                      _startRecording();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // NEW METHOD TO PROCESS USER MESSAGE AND DETECT VIDEO SEARCH
  void _processUserMessage(String transcript) {
    // Check if user wants video search
    final videoSearchKeywords = ['ವೀಡಿಯೊ', 'ವೀಡಿಯೋ', 'video', 'videos', 'ಹುಡುಕಿ', 'ಕಾಣೆ', 'ತೋರಿಸಿ'];
    final containsVideoKeyword = videoSearchKeywords.any((keyword) =>
        transcript.toLowerCase().contains(keyword.toLowerCase()));

    if (containsVideoKeyword) {
      // Extract search query by removing video keywords
      String searchQuery = transcript;
      for (final keyword in videoSearchKeywords) {
        searchQuery = searchQuery.replaceAll(RegExp(keyword, caseSensitive: false), '').trim();
      }

      if (searchQuery.isNotEmpty) {
        _handleVideoSearch(searchQuery);
        return;
      }
    }

    // Otherwise send as normal message
    _sendMessage(transcript);
  }

  void _sendMessage(String transcript) async {
    final messageId = 'user_${DateTime.now().millisecondsSinceEpoch}';

    // Add user message to chat
    final userMessage = ChatMessage(
      id: messageId,
      content: transcript,
      timestamp: DateTime.now(),
      isUser: true,
      audioUrl: null,
    );

    setState(() {
      messages.add(userMessage);
      _showVideoSearch = false; // Hide video search when sending normal message
    });
    _scrollToBottom();

    // Save to Firebase for account users
    if (userMode == 'account') {
      await _firebaseService.saveVisitNote(transcript);
    }

    // Show loading animation
    setState(() => isLoadingAI = true);
    _scrollToBottom();

    try {
      await _callN8NWorkflowAndPlay(transcript);
    } catch (e) {
      debugPrint('N8N response error: $e');
      final errorMessage = ChatMessage(
        id: 'error_${DateTime.now().millisecondsSinceEpoch}',
        content: 'ಕ್ಷಮಿಸಿ, ಪ್ರತಿಕ್ರಿಯೆ ಪಡೆಯಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.',
        timestamp: DateTime.now(),
        isUser: false,
        audioUrl: null,
      );
      setState(() {
        messages.add(errorMessage);
        isLoadingAI = false;
      });
    }

    _scrollToBottom();
  }

  // ADD METHOD TO HANDLE VIDEO SELECTION
  void _onVideoSelected(VideoRecord video) {
    // Add video selection message to chat
    final videoMessage = ChatMessage(
      id: 'video_${DateTime.now().millisecondsSinceEpoch}',
      content: 'ವೀಡಿಯೊ ಆಯ್ಕೆ: ${video.title}',
      timestamp: DateTime.now(),
      isUser: true,
      audioUrl: null,
    );

    setState(() {
      messages.add(videoMessage);
      _showVideoSearch = false; // Hide video search after selection
    });

    _speak('ನೀವು "${video.title}" ವೀಡಿಯೊವನ್ನು ಆಯ್ಕೆ ಮಾಡಿದ್ದೀರಿ. ಶೀಘ್ರದಲ್ಲೇ ವೀಡಿಯೊ ಪ್ಲೇಯರ್ ಸೇರಿಸಲಾಗುವುದು.');

    // TODO: Integrate with your video player
    debugPrint('Selected video: ${video.title} - ${video.videoUrl}');
  }

  // ADD METHOD TO TOGGLE VIDEO SEARCH
  void _toggleVideoSearch() {
    setState(() {
      _showVideoSearch = !_showVideoSearch;
      if (_showVideoSearch) {
        _videoResults.clear();
      }
    });
  }

  Future<void> _callN8NWorkflowAndPlay(String userMessage) async {
    try {
      final requestBody = {
        'userMessage': userMessage,
        'userMode': userMode ?? 'general',
        'language': 'kannada',
        'timestamp': DateTime.now().toIso8601String(),
        'responseType': 'audio',
      };

      final response = await http.post(
        Uri.parse(n8nWebhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(n8nResponseTimeout);

      if (response.statusCode == 200) {
        await _handleN8NResponse(response);
      } else {
        throw Exception('ಸರ್ವರ್ ತಪ್ಪು: ${response.statusCode}');
      }
    } catch (e) {
      await _speak('ಕ್ಷಮಿಸಿ, ಪ್ರತಿಕ್ರಿಯೆ ಪಡೆಯಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.');
      rethrow;
    } finally {
      setState(() => isLoadingAI = false);
    }
  }

  Future<void> _handleN8NResponse(http.Response response) async {
    try {
      final contentType = response.headers['content-type']?.toLowerCase() ?? '';

      if (contentType.contains('application/json') || _looksLikeJson(response.bodyBytes)) {
        await _handleJsonResponse(response);
      } else if (contentType.contains('audio/')) {
        await _playAudioFromBytes(response.bodyBytes, contentType);
      } else {
        await _handleUnknownResponse(response.bodyBytes, contentType);
      }
    } catch (e) {
      debugPrint('N8N response handling error: $e');
      rethrow;
    }
  }

  bool _looksLikeJson(List<int> bytes) {
    try {
      if (bytes.isEmpty) return false;
      final firstChar = utf8.decode([bytes[0]]);
      return firstChar == '{' || firstChar == '[';
    } catch (e) {
      return false;
    }
  }

  Future<void> _handleJsonResponse(http.Response response) async {
    try {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));

      if (jsonResponse is Map) {
        if (jsonResponse['type'] == 'Buffer' && jsonResponse['data'] is List) {
          await _handleBufferObject(jsonResponse);
        } else if (jsonResponse['audio'] != null || jsonResponse['data'] != null) {
          await _handleAudioDataInJson(jsonResponse);
        } else if (jsonResponse['text'] != null || jsonResponse['output'] != null) {
          await _handleTextResponse(jsonResponse);
        } else {
          await _extractAndSpeakText(jsonResponse);
        }
      }
    } catch (e) {
      debugPrint('JSON handling error: $e');
      rethrow;
    }
  }

  Future<void> _handleBufferObject(Map bufferObject) async {
    try {
      final bufferData = bufferObject['data'];
      if (bufferData is List) {
        final audioBytes = bufferData.cast<int>().toList();
        await _playAudioFromBytes(audioBytes, 'audio/mpeg');
      }
    } catch (e) {
      debugPrint('Buffer object handling error: $e');
      await _handleTextFallback(bufferObject, 'ಆಡಿಯೋ ಡೇಟಾ ಪ್ರಕ್ರಿಯೆಗೊಳಿಸಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.');
    }
  }

  Future<void> _handleAudioDataInJson(Map jsonResponse) async {
    try {
      if (jsonResponse['audio'] is Map && jsonResponse['audio']['data'] is List) {
        await _handleBufferObject(jsonResponse['audio']);
      } else if (jsonResponse['data'] is List) {
        final audioBytes = (jsonResponse['data'] as List).cast<int>().toList();
        await _playAudioFromBytes(audioBytes, 'audio/mpeg');
      } else if (jsonResponse['audio'] is String) {
        await _handleBase64Audio(jsonResponse['audio'], 'audio/mpeg');
      } else {
        throw Exception('ಯಾವುದೇ ಆಡಿಯೋ ಡೇಟಾ ಕಂಡುಬಂದಿಲ್ಲ');
      }
    } catch (e) {
      debugPrint('Audio data in JSON handling error: $e');
      rethrow;
    }
  }

  Future<void> _handleTextResponse(Map jsonResponse) async {
    try {
      final textResponse = jsonResponse['text'] ?? jsonResponse['output'] ?? jsonResponse['message'] ?? 'ಪ್ರತಿಕ್ರಿಯೆ ಲಭ್ಯವಿಲ್ಲ';

      // Add AI response as text message
      final aiMessage = ChatMessage(
        id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
        content: textResponse.toString(),
        timestamp: DateTime.now(),
        isUser: false,
        audioUrl: null,
      );

      setState(() {
        messages.add(aiMessage);
      });

      await _speak(textResponse.toString());
    } catch (e) {
      debugPrint('Text response handling error: $e');
      throw Exception('ಪ್ರತಿಕ್ರಿಯೆ ಪ್ರಕ್ರಿಯೆಗೊಳಿಸಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ');
    }
  }

  Future<void> _extractAndSpeakText(Map jsonResponse) async {
    final textContent = _findTextContent(jsonResponse);
    if (textContent.isNotEmpty) {
      await _speak(textContent);
    } else {
      throw Exception('ಯಾವುದೇ ಪಠ್ಯ ಅಥವಾ ಆಡಿಯೋ ಡೇಟಾ ಕಂಡುಬಂದಿಲ್ಲ');
    }
  }

  String _findTextContent(dynamic data, {int depth = 0}) {
    if (depth > 5) return '';
    if (data is String) return data.length < 1000 ? data : '';
    if (data is Map) {
      final commonTextFields = ['text', 'output', 'message', 'response', 'content'];
      for (final field in commonTextFields) {
        if (data[field] is String && data[field].toString().isNotEmpty) {
          return data[field].toString();
        }
      }
      for (final value in data.values) {
        final result = _findTextContent(value, depth: depth + 1);
        if (result.isNotEmpty) return result;
      }
    }
    if (data is List) {
      for (final item in data) {
        final result = _findTextContent(item, depth: depth + 1);
        if (result.isNotEmpty) return result;
      }
    }
    return '';
  }

  Future<void> _handleTextFallback(Map jsonResponse, String fallbackMessage) async {
    final textContent = _findTextContent(jsonResponse);
    if (textContent.isNotEmpty) {
      await _speak(textContent);
    } else {
      await _speak(fallbackMessage);
    }
  }

  Future<void> _handleBase64Audio(String audioData, String mimeType) async {
    try {
      final audioBytes = base64.decode(audioData);
      await _playAudioFromBytes(audioBytes, mimeType);
    } catch (e) {
      debugPrint('Base64 audio handling error: $e');
      throw Exception('ಆಡಿಯೋ ಡೇಟಾ ಡಿಕೋಡ್ ಮಾಡಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ');
    }
  }

  Future<void> _playAudioFromBytes(List<int> audioBytes, String contentType) async {
    try {
      setState(() => isPlaying = true);

      final Uint8List audioData = Uint8List.fromList(audioBytes);
      await audioService.playAudioBytes(audioData, contentType);

      // Add AI response as audio message
      final aiMessage = ChatMessage(
        id: 'audio_${DateTime.now().millisecondsSinceEpoch}',
        content: 'ಆಡಿಯೋ ಪ್ರತಿಕ್ರಿಯೆ',
        timestamp: DateTime.now(),
        isUser: false,
        audioUrl: null,
      );

      setState(() {
        messages.add(aiMessage);
        isPlaying = false;
        _currentlyPlayingMessageId = null;
      });

    } catch (e) {
      debugPrint('❌ Audio playback error: $e');
      setState(() {
        isPlaying = false;
        _currentlyPlayingMessageId = null;
      });
      await _speak('ಆಡಿಯೋ ಸಮಸ್ಯೆ, ಪಠ್ಯ ಪ್ರತಿಕ್ರಿಯೆ ನೀಡುತ್ತಿದೆ.');
    }
  }

  Future<void> _handleUnknownResponse(List<int> bodyBytes, String contentType) async {
    try {
      final text = utf8.decode(bodyBytes);
      if (text.length < 1000 && !text.contains('�')) {
        await _speak(text);
        return;
      }
    } catch (e) {
      debugPrint('Text decoding failed: $e');
    }

    try {
      await _playAudioFromBytes(bodyBytes, contentType);
    } catch (e) {
      debugPrint('Audio playback failed: $e');
      await _speak('ಕ್ಷಮಿಸಿ, ಪ್ರತಿಕ್ರಿಯೆ ಸ್ವೀಕರಿಸಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleClearData() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ಚಾಟ್ ಇತಿಹಾಸ ಅಳಿಸಿ'),
        content: const Text('ನೀವು ಖಚಿತವಾಗಿ ಎಲ್ಲಾ ಸಂಭಾಷಣೆ ಇತಿಹಾಸವನ್ನು ಅಳಿಸಲು ಬಯಸುವಿರಾ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ರದ್ದು'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                messages.clear();
                _showVideoSearch = false;
                _videoResults.clear();
              });
              _speak('ಸಂಭಾಷಣೆ ಇತಿಹಾಸ ಅಳಿಸಲಾಗಿದೆ.');
            },
            child: const Text('ಅಳಿಸಿ'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _recordingTimer.cancel();
    ttsService.stop();
    speechService.stop();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _navigateToWelcome,
                    tooltip: 'ಹಿಂದೆ',
                  ),
                  const Text('ಧ್ವನಿ ಸಹಾಯಕ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      // ADD VIDEO SEARCH TOGGLE BUTTON
                      IconButton(
                        icon: Icon(
                          _showVideoSearch ? Icons.chat : Icons.video_library,
                          color: _showVideoSearch ? const Color(0xFF00796B) : null,
                        ),
                        onPressed: _toggleVideoSearch,
                        tooltip: _showVideoSearch ? 'ಚಾಟಿಂಗ್ ಗೆ ಹಿಂತಿರುಗಿ' : 'ವೀಡಿಯೊ ಹುಡುಕಾಟ',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _handleClearData,
                        tooltip: 'ಚಾಟ್ ಅಳಿಸಿ',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Chat Messages OR Video Search
            Expanded(
              child: _showVideoSearch
                  ? _buildVideoSearchUI() // ADD THIS
                  : _buildChatUI(), // MODIFIED THIS
            ),

            // Recording/Input Area (only show in chat mode)
            if (!_showVideoSearch) _buildInputArea(),
          ],
        ),
      ),
    );
  }

  // ADD VIDEO SEARCH UI METHOD
  Widget _buildVideoSearchUI() {
    return Column(
      children: [
        // Video Search Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF00796B),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.video_library, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Text(
                'ಶೈಕ್ಷಣಿಕ ವೀಡಿಯೊಗಳು',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: VideoSearchWidget(
            onVideoSelected: _onVideoSelected,
            showSearchBar: true,
          ),
        ),
      ],
    );
  }

  // MODIFIED CHAT UI METHOD
  Widget _buildChatUI() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: messages.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('ಸಂಭಾಷಣೆ ಪ್ರಾರಂಭಿಸಲು ಮೈಕ್ರೊಫೋನ್ ಟ್ಯಾಪ್ ಮಾಡಿ'),
            SizedBox(height: 8),
            Text('ಅಥವಾ "ವೀಡಿಯೊಗಳು ಹುಡುಕಿ" ಎಂದು ಹೇಳಿ', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      )
          : ListView.builder(
        controller: _scrollController,
        itemCount: messages.length + (isLoadingAI ? 1 : 0),
        itemBuilder: (context, index) {
          if (isLoadingAI && index == messages.length) {
            return _buildLoadingIndicator();
          }

          final msg = messages[index];
          return _buildMessageBubble(msg);
        },
      ),
    );
  }

  // ADD INPUT AREA METHOD
  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRecording) _buildRecordingUI(),
          if (!isRecording) _buildNormalUI(),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                const Text('ಪ್ರಕ್ರಿಯೆಗೊಳಿಸುತ್ತಿದೆ...'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    final isCurrentlyPlaying = _currentlyPlayingMessageId == msg.id && isPlaying;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85, // ADD THIS CONSTRAINT
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF00796B) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isUser) // Only show for AI messages
                    Row(
                      children: [
                        Icon(Icons.smart_toy, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        const Text('ಸಹಾಯಕ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  const SizedBox(height: 4),
                  // WRAP CONTENT IN FLEXIBLE TO PREVENT OVERFLOW
                  Flexible(
                    child: Text(
                      msg.content,
                      softWrap: true, // ENSURES TEXT WRAPS PROPERLY
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatTime(msg.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: isUser ? Colors.white70 : Colors.grey.shade600,
                        ),
                      ),
                      if (!isUser) // Big play button for AI messages
                        GestureDetector(
                          onTap: () => _playMessageAudio(msg),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isCurrentlyPlaying ? const Color(0xFF00796B) : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF00796B),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              isCurrentlyPlaying ? Icons.stop : Icons.play_arrow,
                              size: 28,
                              color: isCurrentlyPlaying ? Colors.white : const Color(0xFF00796B),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }



  Future<void> _playMessageAudio(ChatMessage msg) async {
    if (_currentlyPlayingMessageId == msg.id && isPlaying) {
      // Stop if already playing
      setState(() {
        isPlaying = false;
        _currentlyPlayingMessageId = null;
      });
      await ttsService.stop();
    } else {
      // Play this message
      setState(() {
        _currentlyPlayingMessageId = msg.id;
        isPlaying = true;
      });
      await _speak(msg.content);
      setState(() {
        isPlaying = false;
        _currentlyPlayingMessageId = null;
      });
    }
  }

  Widget _buildRecordingUI() {
    return Column(
      children: [
        // Recording animation
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic, color: Colors.red, size: 32), // Bigger mic icon
            const SizedBox(width: 12),
            Text(
              'ರೆಕಾರ್ಡಿಂಗ್... ${_recordingDuration.inSeconds}ಸೆ',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.red,
                fontSize: 18, // Bigger text
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Waveform animation (simplified)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(7, (index) { // More bars for better visual
            final height = 15 + (DateTime.now().millisecond % 25); // Taller bars
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 6, // Wider bars
              height: height.toDouble(),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF00796B),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),

        // Big Cancel button
        if (_showCancelOption)
          SizedBox(
            width: 140, // Bigger button
            height: 50, // Bigger button
            child: ElevatedButton.icon(
              icon: const Icon(Icons.cancel, size: 24),
              label: const Text('ರದ್ದು ಮಾಡಿ', style: TextStyle(fontSize: 16)),
              onPressed: _cancelRecording,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNormalUI() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _startRecording,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), // Bigger padding
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(30), // More rounded
              ),
              child: Row(
                children: [
                  Icon(Icons.mic_none, size: 28, color: Colors.grey.shade600), // Bigger icon
                  const SizedBox(width: 12),
                  Text(
                    'ಸಂದೇಶ ರೆಕಾರ್ಡ್ ಮಾಡಲು ಟ್ಯಾಪ್ ಮಾಡಿ...',
                    style: TextStyle(
                      fontSize: 16, // Bigger text
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Big recording button
        Container(
          width: 60, // Much bigger button
          height: 60, // Much bigger button
          decoration: BoxDecoration(
            color: const Color(0xFF00796B),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00796B).withOpacity(0.3)
                ,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.mic, size: 32, color: Colors.white), // Bigger icon
            onPressed: _startRecording,
          ),
        ),
      ],
    );
  }
}

class ChatMessage {
  final String id;
  final String content;
  final DateTime timestamp;
  final bool isUser;
  final String? audioUrl;

  ChatMessage({
    required this.id,
    required this.content,
    required this.timestamp,
    required this.isUser,
    this.audioUrl,
  });
}