import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'services/tts_service.dart';
import 'services/speech_service.dart';
import 'services/voice_identity_service.dart';
import 'services/firebase_service.dart';
import 'voice_interface_page.dart';
import 'voice_signup_page.dart';
import 'dashboard.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool isListening = false;
  bool isSpeaking = false;
  String transcript = '';
  List<UserAccount> existingUsers = [];
  String? selectedUsername;
  DateTime? selectedUserLMP;
  String _currentFlow = 'initial'; // 'initial', 'select_account', 'verify_lmp'

  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareServices();
      _loadExistingUsers();
    });
  }

  // SAFE NAVIGATION METHODS
  void _navigateToVoice() {
    try {
      Navigator.pushReplacementNamed(context, '/voice');
    } catch (e) {
      debugPrint('Navigation to voice failed: $e');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const VoiceInterfacePage()),
            (route) => false,
      );
    }
  }

  void _navigateToSignup() {
    try {
      Navigator.pushNamed(context, '/signup');
    } catch (e) {
      debugPrint('Navigation to signup failed: $e');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const VoiceSignupPage()),
      );
    }
  }

  void _navigateToDashboard() {
    try {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } catch (e) {
      debugPrint('Navigation to dashboard failed: $e');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const DashboardPage()),
            (route) => false,
      );
    }
  }

  // Load all existing users from shared preferences
  Future<void> _loadExistingUsers() async {
    final prefs = await SharedPreferences.getInstance();

    // Get all stored usernames and their data
    final allUsernames = prefs.getString('allUsernames')?.split(',') ?? [];

    final List<UserAccount> users = [];

    for (final username in allUsernames) {
      if (username.isNotEmpty) {
        final lmpStr = prefs.getString('${username}_lmpDate');
        final userMode = prefs.getString('${username}_userMode');

        users.add(UserAccount(
          username: username,
          lmpDate: lmpStr != null ? DateTime.tryParse(lmpStr) : null,
          userMode: userMode,
        ));
      }
    }

    setState(() {
      existingUsers = users;
    });

    await Future.delayed(const Duration(seconds: 1));

    if (existingUsers.isNotEmpty) {
      if (existingUsers.length == 1) {
        // Single user - ask if they want to continue with that account
        final user = existingUsers.first;
        await _speak('ನಮಸ್ಕಾರ! ನೀವು ${user.username} ಖಾತೆಯೊಂದಿಗೆ ಮುಂದುವರೆಯಲು ಬಯಸುವಿರಾ? ಹೌದು, ಇಲ್ಲ, ಅಥವಾ ಹೊಸ ಖಾತೆ ರಚಿಸಿ ಎಂದು ಹೇಳಿ.');
      } else {
        // Multiple users - ask which account to use
        final userNames = existingUsers.map((user) => user.username).join(', ');
        await _speak('ನಮಸ್ಕಾರ! ನಿಮ್ಮ ಖಾತೆಗಳು: $userNames. ಯಾವ ಖಾತೆಯೊಂದಿಗೆ ಮುಂದುವರೆಯಲು ಬಯಸುವಿರಾ? ಹೆಸರು ಹೇಳಿ, ಅಥವಾ ಹೊಸ ಖಾತೆ ರಚಿಸಿ ಎಂದು ಹೇಳಿ.');
        setState(() {
          _currentFlow = 'select_account';
        });
      }
    } else {
      // New user
      await _speak('ನಮಸ್ಕಾರ! ಖಾತೆಯನ್ನು ರಚಿಸಲು ಬಯಸುವಿರಾ? ಹೌದು ಅಥವಾ ಇಲ್ಲ ಎಂದು ಹೇಳಿ.');
    }
  }

  Future<void> _startListeningForResponse() async {
    if (isSpeaking) {
      await _speak('ದಯವಿಟ್ಟು ಕೆಲವು ಕ್ಷಣಗಳಲ್ಲಿ ಪ್ರಯತ್ನಿಸಿ. ನಾನು ಇನ್ನೂ ಮಾತನಾಡುತ್ತಿದ್ದೇನೆ.');
      return;
    }

    final ok = await speechService.initialize();
    if (!ok) {
      await _speak('ಕ್ಷಮಿಸಿ, ಮೈಕ್ರೊಫೋನ್ ಲಭ್ಯವಿಲ್ಲ.');
      return;
    }

    setState(() {
      isListening = true;
      transcript = '';
    });

    try {
      await speechService.startListeningWithRetry((text, isFinal) {
        if (!mounted) return;
        setState(() => transcript = text);

        if (isFinal && text.isNotEmpty) {
          setState(() => isListening = false);
          _handleUserResponse(text);
        } else if (isFinal) {
          setState(() => isListening = false);
        }
      }, localeId: 'kn-IN', retries: 2, attemptTimeout: const Duration(seconds: 10));
    } catch (e) {
      if (mounted) setState(() => isListening = false);
    }
  }

  void _handleUserResponse(String text) async {
    final lower = text.toLowerCase();

    if (_currentFlow == 'initial') {
      await _handleInitialResponse(lower);
    } else if (_currentFlow == 'select_account') {
      await _handleAccountSelection(lower);
    } else if (_currentFlow == 'verify_lmp') {
      await _handleLMPVerification(lower);
    }
  }

  Future<void> _handleInitialResponse(String response) async {
    if (existingUsers.isNotEmpty) {
      // Returning user flow
      if (response.contains('ಹೌದು') || response.contains('yes')) {
        if (existingUsers.length == 1) {
          // Single user - continue directly
          await _continueWithAccount(existingUsers.first);
        } else {
          // Multiple users - ask which one
          final userNames = existingUsers.map((user) => user.username).join(', ');
          await _speak('ಯಾವ ಖಾತೆಯೊಂದಿಗೆ ಮುಂದುವರೆಯಲು ಬಯಸುವಿರಾ? ಹೆಸರು ಹೇಳಿ: $userNames');
          setState(() {
            _currentFlow = 'select_account';
          });
        }
      } else if (response.contains('ಇಲ್ಲ') || response.contains('no')) {
        await _handleAnonymous();
      } else if (response.contains('ಹೊಸ') || response.contains('new') || response.contains('ರಚಿಸಿ')) {
        await _handleStoreInformation();
      } else {
        await _speak('ಕ್ಷಮಿಸಿ, ನಾನು ಅರ್ಥಮಾಡಿಕೊಳ್ಳಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಹೌದು, ಇಲ್ಲ, ಅಥವಾ ಹೊಸ ಖಾತೆ ರಚಿಸಿ ಎಂದು ಹೇಳಿ.');
        await _startListeningForResponse();
      }
    } else {
      // New user flow
      if (response.contains('ಹೌದು') || response.contains('yes')) {
        await _handleStoreInformation();
      } else if (response.contains('ಇಲ್ಲ') || response.contains('no')) {
        await _handleAnonymous();
      } else {
        await _speak('ಕ್ಷಮಿಸಿ, ನಾನು ಅರ್ಥಮಾಡಿಕೊಳ್ಳಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಹೌದು ಅಥವಾ ಇಲ್ಲ ಎಂದು ಹೇಳಿ.');
        await _startListeningForResponse();
      }
    }
  }

  Future<void> _handleAccountSelection(String response) async {
    // Try to find matching username
    UserAccount? selectedAccount;

    for (final user in existingUsers) {
      if (response.contains(user.username.toLowerCase())) {
        selectedAccount = user;
        break;
      }
    }

    if (selectedAccount != null) {
      setState(() {
        selectedUsername = selectedAccount!.username;
        selectedUserLMP = selectedAccount.lmpDate;
        _currentFlow = 'verify_lmp';
      });

      if (selectedUserLMP != null) {
        final formattedDate = _formatDateForSpeech(selectedUserLMP!);
        await _speak('ನಿಮ್ಮ ಕೊನೆಯ ಋತುಚಕ್ರದ ಪ್ರಥಮ ದಿನಾಂಕ $formattedDate ಆಗಿದೆಯೇ? ಹೌದು ಅಥವಾ ಇಲ್ಲ ಎಂದು ಹೇಳಿ.');
      } else {
        await _speak('ನಿಮ್ಮ ಕೊನೆಯ ಋತುಚಕ್ರದ ಪ್ರಥಮ ದಿನಾಂಕ ಏನು? ದಯವಿಟ್ಟು ದಿನಾಂಕ ಹೇಳಿ.');
      }
    } else if (response.contains('ಹೊಸ') || response.contains('new') || response.contains('ರಚಿಸಿ')) {
      await _handleStoreInformation();
    } else if (response.contains('ಅನಾಮಧೇಯ') || response.contains('anonymous') || response.contains('ಇಲ್ಲ')) {
      await _handleAnonymous();
    } else {
      final userNames = existingUsers.map((user) => user.username).join(', ');
      await _speak('ಕ್ಷಮಿಸಿ, ನಾನು ಹೆಸರು ಅರ್ಥಮಾಡಿಕೊಳ್ಳಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಈ ಹೆಸರುಗಳಲ್ಲಿ ಒಂದನ್ನು ಹೇಳಿ: $userNames, ಅಥವಾ ಹೊಸ ಖಾತೆ ರಚಿಸಿ ಎಂದು ಹೇಳಿ.');
      await _startListeningForResponse();
    }
  }

  Future<void> _handleLMPVerification(String response) async {
    if (response.contains('ಹೌದು') || response.contains('yes')) {
      // LMP matches - continue to existing account
      await _continueWithAccount(UserAccount(
        username: selectedUsername!,
        lmpDate: selectedUserLMP,
        userMode: 'account',
      ));
    } else if (response.contains('ಇಲ್ಲ') || response.contains('no')) {
      // LMP doesn't match - ask if they want to update or create new
      await _speak('ದಿನಾಂಕ ಹೊಂದಿಕೆಯಾಗುವುದಿಲ್ಲ. ಹೊಸ ದಿನಾಂಕವನ್ನು ನವೀಕರಿಸಲು ಬಯಸುವಿರಾ ಅಥವಾ ಹೊಸ ಖಾತೆ ರಚಿಸಲು ಬಯಸುವಿರಾ? ನವೀಕರಿಸಿ ಅಥವಾ ಹೊಸ ಖಾತೆ ಎಂದು ಹೇಳಿ.');

      // Listen for update or new account choice
      final ok = await speechService.initialize();
      if (ok) {
        await speechService.startListeningWithRetry((text, isFinal) {
          if (isFinal && text.isNotEmpty) {
            final lowerText = text.toLowerCase();
            if (lowerText.contains('ನವೀಕರಿಸಿ') || lowerText.contains('update')) {
              _updateLMPForAccount();
            } else if (lowerText.contains('ಹೊಸ') || lowerText.contains('new')) {
              _navigateToSignup();
            } else {
              _speak('ಕ್ಷಮಿಸಿ, ಅರ್ಥಮಾಡಿಕೊಳ್ಳಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ. ಹೊಸ ಖಾತೆ ರಚಿಸಲು ಮುಂದುವರೆಯುತ್ತಿದ್ದೇನೆ.');
              _navigateToSignup();
            }
          }
        }, localeId: 'kn-IN');
      }
    } else {
      // Try to extract date from response
      final extractedDate = _extractDateFromText(response);
      if (extractedDate != null) {
        await _verifyExtractedDate(extractedDate);
      } else {
        await _speak('ಕ್ಷಮಿಸಿ, ನಾನು ದಿನಾಂಕ ಅರ್ಥಮಾಡಿಕೊಳ್ಳಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಹೌದು ಅಥವಾ ಇಲ್ಲ ಎಂದು ಹೇಳಿ.');
        await _startListeningForResponse();
      }
    }
  }

  Future<void> _updateLMPForAccount() async {
    await _speak('ದಯವಿಟ್ಟು ಹೊಸ ದಿನಾಂಕವನ್ನು ಹೇಳಿ.');

    final ok = await speechService.initialize();
    if (ok) {
      await speechService.startListeningWithRetry((text, isFinal) {
        if (isFinal && text.isNotEmpty) {
          final parsedDate = _extractDateFromText(text);
          if (parsedDate != null) {
            _saveUpdatedLMP(parsedDate);
          } else {
            _speak('ದಿನಾಂಕ ಅರ್ಥಮಾಡಿಕೊಳ್ಳಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ. ಹೊಸ ಖಾತೆ ರಚಿಸಲು ಮುಂದುವರೆಯುತ್ತಿದ್ದೇನೆ.');
            _navigateToSignup();
          }
        }
      }, localeId: 'kn-IN');
    }
  }

  Future<void> _saveUpdatedLMP(DateTime newLMP) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${selectedUsername}_lmpDate', newLMP.toIso8601String());

    // Update current session
    await prefs.setString('userMode', 'account');
    await prefs.setString('username', selectedUsername!);
    await prefs.setString('lmpDate', newLMP.toIso8601String());

    await _speak('ದಿನಾಂಕ ನವೀಕರಿಸಲಾಗಿದೆ. ಡ್ಯಾಶ್‌ಬೋರ್ಡ್‌ಗೆ ಮುಂದುವರೆಯುತ್ತಿದ್ದೇನೆ.');
    _navigateToDashboard();
  }

  DateTime? _extractDateFromText(String text) {
    try {
      final now = DateTime.now();

      if (text.contains('ಇಂದು') || text.contains('today')) {
        return now;
      }

      if (text.contains('ನಿನ್ನೆ') || text.contains('yesterday')) {
        return now.subtract(const Duration(days: 1));
      }

      // Add more sophisticated date parsing as needed
      return null;
    } catch (e) {
      debugPrint('Date extraction error: $e');
      return null;
    }
  }

  Future<void> _verifyExtractedDate(DateTime extractedDate) async {
    if (selectedUserLMP != null) {
      final difference = extractedDate.difference(selectedUserLMP!).inDays.abs();
      if (difference <= 2) {
        await _speak('ದಿನಾಂಕ ಹೊಂದಿಕೆಯಾಗಿದೆ. ಡ್ಯಾಶ್‌ಬೋರ್ಡ್‌ಗೆ ಮುಂದುವರೆಯುತ್ತಿದ್ದೇನೆ.');
        _navigateToDashboard();
      } else {
        await _speak('ದಿನಾಂಕ ಹೊಂದಿಕೆಯಾಗುವುದಿಲ್ಲ. ಹೊಸ ಖಾತೆ ರಚಿಸಲು ಮುಂದುವರೆಯುತ್ತಿದ್ದೇನೆ.');
        _navigateToSignup();
      }
    } else {
      await _speak('ಹೊಸ ಖಾತೆ ರಚಿಸಲು ಮುಂದುವರೆಯುತ್ತಿದ್ದೇನೆ.');
      _navigateToSignup();
    }
  }

  String _formatDateForSpeech(DateTime date) {
    final months = [
      'ಜನವರಿ', 'ಫೆಬ್ರವರಿ', 'ಮಾರ್ಚ್', 'ಎಪ್ರಿಲ್', 'ಮೇ', 'ಜೂನ್',
      'ಜುಲೈ', 'ಆಗಸ್ಟ್', 'ಸೆಪ್ಟೆಂಬರ್', 'ಅಕ್ಟೋಬರ್', 'ನವೆಂಬರ್', 'ಡಿಸೆಂಬರ್'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _continueWithAccount(UserAccount user) async {
    // Save selected user as current session
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userMode', user.userMode ?? 'account');
    await prefs.setString('username', user.username);
    if (user.lmpDate != null) {
      await prefs.setString('lmpDate', user.lmpDate!.toIso8601String());
    }

    await _speak('ನಿಮ್ಮ ${user.username} ಖಾತೆಯೊಂದಿಗೆ ಮುಂದುವರೆಯುತ್ತಿದ್ದೇನೆ.');

    if (user.userMode == 'account') {
      _navigateToDashboard();
    } else {
      _navigateToVoice();
    }
  }

  Future<void> _handleStoreInformation() async {
    await _speak('ಖಾತೆ ರಚಿಸಲು ಮುಂದುವರೆಯುತ್ತಿದ್ದೇನೆ.');
    _navigateToSignup();
  }

  Future<void> _handleAnonymous() async {
    try {
      final user = await _firebaseService.signInAnonymously();
      if (user != null) {
        await _firebaseService.createUserProfile(
            username: 'ಅತಿಥಿ',
            lmpDate: DateTime.now(),
            isAnonymous: true
        );

        await voiceIdentityService.createVoiceIdentity('ಅತಿಥಿ');

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userMode', 'anonymous');
        await prefs.setBool('isAnonymous', true);
        await prefs.setString('username', 'ಅತಿಥಿ');
        await prefs.setString('lmpDate', DateTime.now().toIso8601String());

        // Add to existing users list
        await _addUserToExistingList('ಅತಿಥಿ');

        await _speak('ಅನಾಮಧೇಯವಾಗಿ ಮುಂದುವರಿಯುತ್ತಿದ್ದೇನೆ.');
        _navigateToVoice();
      }
    } catch (e) {
      debugPrint('Anonymous error: $e');
      await _speak('ಕ್ಷಮಿಸಿ, ಪ್ರವೇಶದಲ್ಲಿ ಸಮಸ್ಯೆ ಉಂಟಾಗಿದೆ.');
    }
  }

  // Helper method to add user to existing users list
  Future<void> _addUserToExistingList(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUsers = prefs.getString('allUsernames')?.split(',') ?? [];

    if (!currentUsers.contains(username)) {
      currentUsers.add(username);
      await prefs.setString('allUsernames', currentUsers.join(','));
    }
  }

  Future<void> _prepareServices() async {
    await ttsService.setSpeechRate(0.4);
    await ttsService.setPitch(1.0);
    await speechService.initialize();
    if (!mounted) return;
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    try {
      setState(() => isSpeaking = true);
      await ttsService.speak(text);
    } catch (e) {
      debugPrint('TTS speak error: $e');
    } finally {
      if (mounted) setState(() => isSpeaking = false);
    }
  }

  Future<void> _toggleListening() async {
    if (isSpeaking) return;
    if (!isListening) {
      await _startListeningForResponse();
    } else {
      await speechService.stop();
      setState(() => isListening = false);
    }
  }

  String _getQuestionText() {
    if (_currentFlow == 'select_account') {
      return 'ಯಾವ ಖಾತೆಯೊಂದಿಗೆ ಮುಂದುವರೆಯಲು ಬಯಸುವಿರಾ?';
    } else if (_currentFlow == 'verify_lmp') {
      if (selectedUserLMP != null) {
        final formattedDate = _formatDateForSpeech(selectedUserLMP!);
        return 'ನಿಮ್ಮ ಕೊನೆಯ ಋತುಚಕ್ರದ ಪ್ರಥಮ ದಿನಾಂಕ $formattedDate ಆಗಿದೆಯೇ?';
      } else {
        return 'ನಿಮ್ಮ ಕೊನೆಯ ಋತುಚಕ್ರದ ಪ್ರಥಮ ದಿನಾಂಕ ಏನು?';
      }
    } else {
      if (existingUsers.isNotEmpty) {
        if (existingUsers.length == 1) {
          return 'ನಮಸ್ಕಾರ ${existingUsers.first.username}! ನಿಮ್ಮ ಖಾತೆಯೊಂದಿಗೆ ಮುಂದುವರೆಯಲು ಬಯಸುವಿರಾ?';
        } else {
          return 'ನಿಮ್ಮ ಖಾತೆಗಳು: ${existingUsers.map((user) => user.username).join(', ')}';
        }
      } else {
        return 'ನಿಮ್ಮ ಮಾಹಿತಿಯನ್ನು ಶೇಖರಿಸಲು ನೀವು ಬಯಸುವಿರಾ?';
      }
    }
  }

  String _getSubtitleText() {
    if (_currentFlow == 'select_account') {
      final userNames = existingUsers.map((user) => user.username).join(', ');
      return 'ಹೆಸರು ಹೇಳಿ: $userNames, ಅಥವಾ "ಹೊಸ ಖಾತೆ"';
    } else if (_currentFlow == 'verify_lmp') {
      return 'ಹೌದು ಅಥವಾ ಇಲ್ಲ ಎಂದು ಹೇಳಿ';
    } else {
      if (existingUsers.isNotEmpty) {
        return 'ಹೌದು, ಇಲ್ಲ, ಅಥವಾ ಹೊಸ ಖಾತೆ ರಚಿಸಿ ಎಂದು ಹೇಳಿ';
      } else {
        return 'ಹೌದು ಅಥವಾ ಇಲ್ಲ ಎಂದು ಹೇಳಿ';
      }
    }
  }

  @override
  void dispose() {
    speechService.cancel();
    ttsService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Minimal Logo/Image
                  CircleAvatar(
                    radius: min(screenHeight * 0.075, 80.0),
                    backgroundColor: const Color(0x1A00796B),
                    backgroundImage: const AssetImage('assets/images/maternal-hero.jpg'),
                  ),
                  const SizedBox(height: 40),

                  // Main Heading Only
                  Text(
                    'ಮಾತೃತ್ವ ಆರೋಗ್ಯ ಸಹಾಯಕ',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontSize: screenHeight * 0.03,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Single Question Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getQuestionText(),
                            style: theme.textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 8),

                          Text(
                            _getSubtitleText(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[700],
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 16),

                          if (transcript.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: const Color(0x0D1976D2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0x331976D2)),
                              ),
                              child: Text(
                                '"$transcript"',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Color(0xFF1976D2),
                                ),
                              ),
                            ),

                          GestureDetector(
                            onTap: _toggleListening,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isListening ? const Color(0xFFD32F2F) : const Color(0xFF1976D2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color.fromRGBO(0, 0, 0, 0.2),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Icon(
                                isListening ? Icons.mic : Icons.mic_none,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          Text(
                            isListening
                                ? 'ಕೇಳುತ್ತಿದೆ... ಮಾತನಾಡಿ'
                                : (isSpeaking
                                ? 'ಮಾತನಾಡುತ್ತಿದೆ...'
                                : 'ಮಾತನಾಡಲು ಟ್ಯಾಪ್ ಮಾಡಿ'),
                            style: theme.textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class UserAccount {
  final String username;
  final DateTime? lmpDate;
  final String? userMode;

  UserAccount({
    required this.username,
    this.lmpDate,
    this.userMode,
  });
}