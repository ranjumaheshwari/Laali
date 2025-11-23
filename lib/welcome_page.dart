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
  bool _speechReady = false;
  String transcript = '';
  bool _loading = false;
  String? returningUsername;

  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareServices();
      _checkReturningUser();
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

  Future<void> _checkReturningUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userMode = prefs.getString('userMode');
    final username = prefs.getString('username');

    if (userMode == 'account' && username != null) {
      setState(() => returningUsername = username);
      await Future.delayed(const Duration(seconds: 1));
      await _speak('ನಮಸ್ಕಾರ! ನೀವು $username ಖಾತೆಯೊಂದಿಗೆ ಮುಂದುವರೆಯಲು ಬಯಸುವಿರಾ? ಹೌದು ಅಥವಾ ಇಲ್ಲ ಎಂದು ಹೇಳಿ.');
    } else {
      await Future.delayed(const Duration(seconds: 1));
      await _speak('ನಿಮ್ಮ ಮಾಹಿತಿಯನ್ನು ಶೇಖರಿಸಲು ನೀವು ಬಯಸುವಿರಾ? ಹೌದು ಅಥವಾ ಇಲ್ಲ ಎಂದು ಹೇಳಿ.');
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

    if (returningUsername != null) {
      // Returning user flow
      if (lower.contains('ಹೌದು') || lower.contains('yes')) {
        await _continueWithAccount();
      } else if (lower.contains('ಇಲ್ಲ') || lower.contains('no')) {
        await _startAsAnonymous();
      } else {
        await _speak('ಕ್ಷಮಿಸಿ, ನಾನು ಅರ್ಥಮಾಡಿಕೊಳ್ಳಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಹೌದು ಅಥವಾ ಇಲ್ಲ ಎಂದು ಹೇಳಿ.');
        await _startListeningForResponse();
      }
    } else {
      // New user flow
      if (lower.contains('ಹೌದು') || lower.contains('yes')) {
        await _handleStoreInformation();
      } else if (lower.contains('ಇಲ್ಲ') || lower.contains('no')) {
        await _handleAnonymous();
      } else {
        await _speak('ಕ್ಷಮಿಸಿ, ನಾನು ಅರ್ಥಮಾಡಿಕೊಳ್ಳಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಹೌದು ಅಥವಾ ಇಲ್ಲ ಎಂದು ಹೇಳಿ.');
        await _startListeningForResponse();
      }
    }
  }

  Future<void> _continueWithAccount() async {
    await _speak('ನಿಮ್ಮ ಖಾತೆಯೊಂದಿಗೆ ಮುಂದುವರೆಯುತ್ತಿದ್ದೇನೆ.');
    _navigateToDashboard();
  }

  Future<void> _startAsAnonymous() async {
    await _speak('ಅನಾಮಧೇಯವಾಗಿ ಮುಂದುವರೆಯುತ್ತಿದ್ದೇನೆ.');
    await _handleAnonymous();
  }

  Future<void> _handleStoreInformation() async {
    await _speak('ಖಾತೆ ರಚಿಸಲು ಮುಂದುವರೆಯುತ್ತಿದ್ದೇನೆ.');
    _navigateToSignup();
  }

  Future<void> _handleAnonymous() async {
    setState(() => _loading = true);
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

        await _speak('ಅನಾಮಧೇಯವಾಗಿ ಮುಂದುವರಿಯುತ್ತಿದ್ದೇನೆ.');
        _navigateToVoice();
      }
    } catch (e) {
      debugPrint('Anonymous error: $e');
      await _speak('ಕ್ಷಮಿಸಿ, ಪ್ರವೇಶದಲ್ಲಿ ಸಮಸ್ಯೆ ಉಂಟಾಗಿದೆ.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _prepareServices() async {
    await ttsService.setSpeechRate(0.4);
    await ttsService.setPitch(1.0);
    final ok = await speechService.initialize();
    if (!mounted) return;
    setState(() => _speechReady = ok);
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
                          if (returningUsername != null)
                            Text(
                              'ನಮಸ್ಕಾರ $returningUsername!',
                              style: theme.textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            )
                          else
                            Text(
                              'ನಿಮ್ಮ ಮಾಹಿತಿಯನ್ನು ಶೇಖರಿಸಲು ನೀವು ಬಯಸುವಿರಾ?',
                              style: theme.textTheme.titleLarge,
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
                                    color: const Color(0x33000000),
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
                                : 'ಹೌದು ಅಥವಾ ಇಲ್ಲ ಎಂದು ಹೇಳಿ'),
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