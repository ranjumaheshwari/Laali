import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/tts_service.dart';
import 'services/speech_service.dart';
import 'services/voice_identity_service.dart';
import 'services/ai_service.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _showReturningUserOptions = false;
  String? _returningUserName;
  bool _isIdentifyingUser = false;

  bool hasSpokenIntro = false;
  bool isListening = false;
  bool isSpeaking = false;
  bool _speechReady = false;
  String transcript = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareServices();
      _checkAndRecognizeUser();
    });
  }

  // FIXED: Check mounted before setState in async operations
  Future<void> _checkAndRecognizeUser() async {
    final hasUser = await voiceIdentityService.hasExistingUser();
    if (!mounted) return;

    if (hasUser) {
      final profile = await voiceIdentityService.getUserProfile();
      if (!mounted) return;

      if (profile != null) {
        final name = profile['name'] ?? '';
        // Instead of immediate redirect, ask for voice confirmation
        if (!mounted) return;
        setState(() {
          _showReturningUserOptions = true;
          _returningUserName = name;
        });

        // Ask and listen automatically for confirmation
        await _askReturningUserConfirmation(name);
        return;
      }
    }
  }

  /// Speak a prompt and automatically start listening for the user's reply.
  /// The [onFinal] callback will be invoked when the recognizer returns a final result.
  Future<void> _speakThenListen(
    String prompt,
    void Function(String text) onFinal, {
    int retries = 2,
    Duration attemptTimeout = const Duration(seconds: 10),
  }) async {
    await _speak(prompt);
    // start listening with retries; onFinal is called when result is final
    await speechService.startListeningWithRetry((text, isFinal) {
      if (isFinal) {
        try {
          onFinal(text);
        } catch (e) {
          debugPrint('speakThenListen onFinal error: $e');
        }
      } else {
        // update interim transcript
        if (mounted) setState(() => transcript = text);
      }
    },
        localeId: 'kn-IN',
        retries: retries,
        attemptTimeout: attemptTimeout,
        onFailure: () async {
          // If listening fails, prompt the user to tap mic or try again
          await _speak('ಕ್ಷಮಿಸಿ, ನಾನು ನಿಮ್ಮನ್ನು ಕೇಳಲಾರದಿದ್ದು. ದಯವಿಟ್ಟು ಮತ್ತೆ ಮಾತನಾಡಿ ಅಥವಾ ಮೈಕ್ರೊಫೋನನ್ನು ಪರಿಶೀಲಿಸಿ.');
        });
  }

  /// Ask the returning user to confirm their identity by voice and act accordingly.
  Future<void> _askReturningUserConfirmation(String name) async {
    final prompt = 'ನೀವು $name ಅಲ್ಲವೇ? ದಯವಿಟ್ಟು ಹೌದು ಅಥವಾ ಇಲ್ಲ ಎಂದು ಹೇಳಿ.';
    await _speakThenListen(prompt, (text) async {
      final lower = text.toLowerCase();
      debugPrint('Returning user confirmation heard: $text');
      if (lower.contains('ಹೌದು') || lower.contains('yes') || lower.contains('continue') || lower.contains('ಮುಂದುವರ')) {
        // confirmed
        await _speak('ಧನ್ಯವಾದಗಳು $name! ನಿಮನ್ನು ಮುಂದಕ್ಕೆ ಕರೆದೊಯ್ಯುತ್ತಿದ್ದೇನೆ.');
        _continueAsExistingUser();
      } else if (lower.contains('ಇಲ್ಲ') || lower.contains('no') || lower.contains('change')) {
        // not the same person — offer options
        await _speak('ಸರಿ. ನೀವು ಹೊಸ ಬಳಕೆದಾರರಾಗಿದ್ದರೆ, ಖಾತೆ ರಚಿಸಿ ಅಥವಾ ಅನಾಮಧೇಯವಾಗಿ ಮುಂದುವರಿಯಿರಿ.');
        // open signup or anonymous choices automatically by listening again
        await _speakThenListen('ನೀವು ಖಾತೆ ರಚಿಸಬೇಕು ಅಥವಾ ಅನಾಮಧೇಯವಾಗಿರಬೇಕು?', (reply) async {
          final r = reply.toLowerCase();
          if (r.contains('ಖಾತೆ') || r.contains('create') || r.contains('signup')) {
            Navigator.pushNamed(context, '/signup');
          } else {
            await _handleAnonymous();
          }
        });
      } else {
        // unrecognized — ask again once
        await _speak('ಕ್ಷಮಿಸಿ, ನಾನು ಅರ್ಥಮಾಡಿಕೊಳ್ಳಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಹೌದು ಅಥವಾ ಇಲ್ಲ ಎಂದು ಬಾರಿಸಿ.');
        await _askReturningUserConfirmation(name); // recursive one more attempt
      }
    });
  }

  // FIXED: Safe async operations with mounted checks
  Future<void> _prepareServices() async {
    await ttsService.setSpeechRate(0.4);
    await ttsService.setPitch(1.0);

    final ok = await speechService.initialize();
    if (!mounted) return;

    setState(() {
      _speechReady = ok;
    });

    if (!hasSpokenIntro) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        _speak(
          'ಮಾತೃತ್ವ ಆರೋಗ್ಯ ಸಹಾಯಕಕ್ಕೆ ಸ್ವಾಗತ. ನೀವು ಅನಾಮಧೇಯವಾಗಿ ಮುಂದುವರಿಯಲು ಬಯಸುವಿರಾ ಅಥವಾ ಖಾತೆಯನ್ನು ರಚಿಸಲು ಬಯಸುವಿರಾ?',
        );
        if (mounted) {
          setState(() {
            hasSpokenIntro = true;
          });
        }
      });
    }
  }

  // FIXED: Safe speak method with mounted checks
  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    try {
      if (mounted) {
        setState(() {
          isSpeaking = true;
        });
      }
      await ttsService.speak(text);
    } catch (e) {
      debugPrint('TTS speak error: $e');
    } finally {
      if (mounted) {
        setState(() {
          isSpeaking = false;
        });
      }
    }
  }

  // FIXED: Safe listening with mounted checks
  Future<void> _toggleListening() async {
    if (isSpeaking) return;

    if (!isListening) {
      await ttsService.stop();

      final ok = await speechService.initialize();
      if (!ok) {
        if (!mounted) return;
        await _speak('ಕ್ಷಮಿಸಿ, ಮಾತಿನ ಗುರುತಿಸುವಿಕೆ ಲಭ್ಯವಿಲ್ಲ. ದಯವಿಟ್ಟು ಮೈಕ್ರೊಫೋನ್ ಅನುಮತಿಗಳನ್ನು ಪರಿಶೀಲಿಸಿ.');
        if (mounted) {
          setState(() {
            _speechReady = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          isListening = true;
          transcript = '';
          _speechReady = true;
        });
      }

      await speechService.startListeningWithMixedLanguage((text, isFinal) {
        if (!mounted) return;
        debugPrint("🎯 Mixed-language raw result: '$text' final=$isFinal");
        setState(() {
          transcript = text;
        });
        if (isFinal) {
          if (mounted) {
            setState(() {
              isListening = false;
            });
          }
          _onVoiceInput(text);
        }
      });
    } else {
      await speechService.stop();
      if (mounted) {
        setState(() {
          isListening = false;
        });
      }
    }
  }

  // FIXED: Safe voice input handling
  void _onVoiceInput(String text) async {
    final lower = text.toLowerCase();
    debugPrint("🎯 Processing mixed language input: '$text'");

    if (mounted) {
      setState(() {
        transcript = text;
      });
    }

    final anonKeywords = ['ಅನಾಮಧೇಯ', 'anonymous', 'anon', 'guest', 'ಅನಾಮ'];
    final signupKeywords = ['ಖಾತೆ', 'account', 'create', 'sign up', 'ರಚಿಸಿ', 'signup', 'ನೊಂದಾಯಿಸಿ'];

    bool isAnon = anonKeywords.any((k) => lower.contains(k));
    bool isSignup = signupKeywords.any((k) => lower.contains(k));

    if (isAnon) {
      debugPrint("✅ User chose: Anonymous (mixed language detected)");
      await _speak('ನೀವು ಅನಾಮಧೇಯವಾಗಿ ಮುಂದುವರಿಯಲು ನಿರ್ಧರಿಸಿದ್ದೀರಿ. ನಿಮ್ಮನ್ನು ಧ್ವನಿ ಇಂಟರ್ಫೇಸ್ಗೆ ಕರೆದೊಯ್ಯುತ್ತಿದ್ದೇನೆ.');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userMode', 'anonymous');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/voice');
      }
      return;
    }

    if (isSignup) {
      debugPrint("✅ User chose: Sign Up (mixed language detected)");
      await _speak('ಅದ್ಭುತ! ನಾನು ನಿಮಗೆ ಖಾತೆಯನ್ನು ರಚಿಸಲು ಸಹಾಯ ಮಾಡುತ್ತೇನೆ.');
      if (mounted) {
        Navigator.pushNamed(context, '/signup');
      }
      return;
    }

    debugPrint("❌ No matching command found in mixed input — routing to AIService");
    final resp = await aiService.getResponse(text, 'general');
    debugPrint('AI response: $resp');
    await _speak(resp);
  }

  // FIXED: Safe anonymous handler
  Future<void> _handleAnonymous() async {
    await voiceIdentityService.createVoiceIdentity('ಅತಿಥಿ');
    await _speak('ನೀವು ಅನಾಮಧೇಯವಾಗಿ ಮುಂದುವರಿಯಲು ನಿರ್ಧರಿಸಿದ್ದೀರಿ. ನಿಮ್ಮನ್ನು ಧ್ವನಿ ಇಂಟರ್ಫೇಸ್ಗೆ ಕರೆದೊಯ್ಯುತ್ತಿದ್ದೇನೆ.');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userMode', 'anonymous');
    await prefs.setString('lastLogin', DateTime.now().toIso8601String());
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/voice');
    }
  }

  // FIXED: Safe create account handler
  Future<void> _handleCreateAccount() async {
    await _speak('ಅದ್ಭುತ! ನಿಮಗೆ ಖಾತೆ ರಚಿಸಲು ಸಹಾಯ ಮಾಡುತ್ತೇನೆ.');
    if (mounted) {
      Navigator.pushNamed(context, '/signup');
    }
  }

  // FIXED: Safe voice verification
  Future<void> _verifyWithVoice() async {
    if (_isIdentifyingUser) return;
    if (mounted) {
      setState(() => _isIdentifyingUser = true);
    }
    await _speak('ದಯವಿಟ್ಟು ನಿಮ್ಮ ಹೆಸರು ಹೇಳಿ.');
    await speechService.startListening((text, isFinal) {
      if (isFinal && text.isNotEmpty) {
        _processVoiceVerification(text);
      }
    }, localeId: 'kn-IN');
  }

  // FIXED: Safe voice verification processing
  Future<void> _processVoiceVerification(String spokenText) async {
    if (spokenText.trim().isEmpty) {
      await _speak('ದಯವಿಟ್ಟು ನಿಮ್ಮ ಹೆಸರು ಸ್ಪಷ್ಟವಾಗಿ ಹೇಳಿ.');
      if (mounted) {
        setState(() => _isIdentifyingUser = false);
      }
      return;
    }

    final identifiedName = await voiceIdentityService.identifyUserFromVoice(spokenText);

    if (identifiedName != null) {
      await _speak('ಧನ್ಯವಾದಗಳು! ನಿಮ್ಮನ್ನು $identifiedName ಎಂದು ಗುರುತಿಸಲಾಗಿದೆ. ಮುಂದುವರೆಯುತ್ತೇನೆ.');
      _continueAsExistingUser();
    } else {
      await _speak('ಕ್ಷಮಿಸಿ, "$spokenText" ಹೆಸರಿನ ಬಳಕೆದಾರರನ್ನು ಕಂಡುಹಿಡಿಯಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ ಅಥವಾ ಹೊಸ ಖಾತೆ ರಚಿಸಿ.');
    }

    if (mounted) {
      setState(() => _isIdentifyingUser = false);
    }
  }

  void _continueAsExistingUser() async {
    final profile = await voiceIdentityService.getUserProfile();
    if (!mounted) return;

    if (profile != null) {
      if (profile['mode'] == 'anonymous') {
        Navigator.pushReplacementNamed(context, '/voice');
      } else {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    }
  }

  void _startAsNewUser() {
    if (mounted) {
      setState(() {
        _showReturningUserOptions = false;
        _returningUserName = null;
      });
    }
  }

  @override
  void dispose() {
    speechService.cancel();
    ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF7FAFC), Color(0xFFFFFFFF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 110,
                      width: 110,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF56CCF2), Color(0xFF2F80ED)]),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 10)],
                      ),
                      child: const Center(child: Icon(Icons.favorite, size: 48, color: Colors.white)),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'ಮಾತೃತ್ವ ಆರೋಗ್ಯ ಸಹಾಯಕ',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'ನಿಮ್ಮ ಧ್ವನಿ-ಮಾರ್ಗದರ್ಶಿತ ಗರ್ಭಾವಸ್ಥೆಯ ಪ್ರಯಾಣ',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _speechReady ? 'ಮೈಕ್ರೊಫೋನ್ ಸಿದ್ಧವಾಗಿದೆ' : 'ಮೈಕ್ರೊಫೋನ್ ಸಿದ್ಧವಿಲ್ಲ',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 26),

                    if (_showReturningUserOptions && _returningUserName != null)
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: Colors.green[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(
                                '👋 ನಮಸ್ಕಾರ $_returningUserName!',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[800]),
                              ),
                              const SizedBox(height: 8),
                              Text('ನಿಮ್ಮನ್ನು ಮತ್ತೆ ನೋಡಿ ಸಂತೋಷ! ಮುಂದುವರೆಯಲು ಬಯಸುವಿರಾ?', textAlign: TextAlign.center, style: TextStyle(color: Colors.green[700])),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _continueAsExistingUser,
                                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.green)),
                                      child: const Text('ಹೌದು, ಮುಂದುವರೆಸಿ'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _startAsNewUser,
                                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orange)),
                                      child: const Text('ಹೊಸ ಬಳಕೆದಾರ'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton(
                                onPressed: _verifyWithVoice,
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.blue)),
                                child: _isIdentifyingUser
                                    ? const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                    SizedBox(width: 8),
                                    Text('ಗುರುತಿಸುತ್ತಿದೆ...'),
                                  ],
                                )
                                    : const Text('ಧ್ವನಿಯಿಂದ ದೃಢೀಕರಿಸಿ'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (!_showReturningUserOptions) ...[
                      Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            children: [
                              Text(
                                isSpeaking ? 'ಮಾತನಾಡುತ್ತಿದೆ...' : 'ಮೈಕ್ರೊಫೋನ್ ಟ್ಯಾಪ್ ಮಾಡಿ ಮತ್ತು ಮಾತನಾಡಿ',
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 12),

                              if (transcript.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Text('"$transcript"', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 16)),
                                ),

                              const SizedBox(height: 12),

                              GestureDetector(
                                onTap: _toggleListening,
                                child: Container(
                                  width: 180,
                                  height: 180,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isListening ? Colors.red : theme.colorScheme.primary,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(30),
                                        blurRadius: 16,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                    border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.14), width: 3),
                                  ),
                                  child: Icon(
                                    isListening ? Icons.mic : Icons.mic_none,
                                    color: Colors.white,
                                    size: 80,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 14),
                              Text(
                                '"ಅನಾಮಧೇಯ" ಅಥವಾ "ಖಾತೆ ರಚಿಸಿ" ಎಂದು ಹೇಳಿ',
                                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[700], fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      Column(
                        children: [
                          OutlinedButton.icon(
                            onPressed: isSpeaking ? null : _handleAnonymous,
                            icon: const Icon(Icons.person_off, size: 24),
                            label: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: Text('ಅನಾಮಧೇಯವಾಗಿ ಉಳಿಯಿರಿ', style: TextStyle(fontSize: 18)),
                            ),
                            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(64)),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: isSpeaking ? null : _handleCreateAccount,
                            icon: const Icon(Icons.person_add, size: 24),
                            label: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: Text('ಖಾತೆ ರಚಿಸಿ', style: TextStyle(fontSize: 18)),
                            ),
                            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(64)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

