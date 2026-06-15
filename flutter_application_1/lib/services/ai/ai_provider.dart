import '../../models/transaction.dart';

/// SpendSense - AI Provider Interface.
/// Defines the contract for all LLM implementations.
abstract class AiProvider {
  /// The display name of the provider (e.g., 'Claude', 'Gemini').
  String get name;

  /// Tests the provided API key to ensure it is valid and has active billing.
  Future<bool> testApiKey(String apiKey);

  /// Categorises a raw SMS message into a MyTransaction object.
  Future<MyTransaction?> categorise(
    String smsText,
    List<String> categories,
    String apiKey,
  );

  /// Interprets a voice note to update a pending transaction's category, type, and note.
  Future<Map<String, String>> understandVoiceNote(
    String voiceText,
    MyTransaction pending,
    List<String> categories,
    String apiKey,
  );
}
