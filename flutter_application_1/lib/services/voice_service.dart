/// SpendSense — Voice Service
/// Handles speech-to-text input for the notification popup.
/// User taps the mic button and speaks the context:
///   "Lunch with Rahul" → Food
///   "Lent money for bike repair" → Loan
/// Then ClaudeService.understandVoiceNote() extracts category + type.

import 'package:speech_to_text/speech_to_text.dart';

class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  final SpeechToText _stt = SpeechToText();
  bool _isAvailable = false;

  // ── Initialise ────────────────────────────────────────────────────────────
  Future<bool> initialise() async {
    _isAvailable = await _stt.initialize(
      onError: (e) {/* handle gracefully */},
    );
    return _isAvailable;
  }

  // ── Listen and return transcribed text ───────────────────────────────────
  Future<String?> listen(
      {Duration timeout = const Duration(seconds: 8)}) async {
    if (!_isAvailable) return null;

    String? result;

    await _stt.listen(
      onResult: (r) {
        if (r.finalResult) result = r.recognizedWords;
      },
      listenFor: timeout,
      localeId: 'en_IN', // Indian English
    );

    // Wait for result or timeout
    await Future.delayed(timeout + const Duration(milliseconds: 500));
    await _stt.stop();

    return result;
  }

  bool get isListening => _stt.isListening;
}
