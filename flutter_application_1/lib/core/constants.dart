/// SpendSense - Core constants used across the app.

class AppConstants {
  AppConstants._();

  // Anthropic / Claude API
  static const String claudeBaseUrl = 'https://api.anthropic.com/v1/messages';
  static const String claudeModel = 'claude-sonnet-4-6';
  static const String claudeVersion = '2023-06-01';
  static const int claudeMaxTokens = 256;

  // SharedPreferences keys
  static const String prefClaudeApiKey = 'claude_api_key';
  static const String prefWebhookUrl = 'webhook_url';
  static const String legacyPrefWebhookUrl =
      'https://script.google.com/macros/s/AKfycbxmPeL9lhYdbQ0tqaQ0s7rPjJKNGa00-CoK4YZGb3RC7poj2p_Koc6qrWZq8BARJk8w/exec';
  static const String prefOnboardingDone = 'onboarding_done';
  static const String prefDigestTime = 'digest_hour';
  static const String prefBackgroundSmsQueue = 'background_sms_queue';

  // SQLite
  static const String dbName = 'spendsense.db';
  static const int dbVersion = 3;
  static const String transactionsTable = 'transactions';

  // Confidence thresholds
  static const String confidenceHigh = 'HIGH';
  static const String confidenceLow = 'LOW';

  // Transaction types
  static const String typeExpense = 'EXPENSE';
  static const String typeLoan = 'LOAN';

  // Sync statuses
  static const String syncPending = 'pending';
  static const String syncSynced = 'synced';
  static const String syncFailed = 'failed';

  // SMS filter keywords
  static const List<String> smsKeywords = [
    'debited',
    'deducted',
    'paid',
    'transferred',
    'sent',
    'inr',
    'rs.',
    'rs ',
    'credited',
    'upi ref',
    'upi',
    'successful',
    'received',
    'amount',
    '₹',
  ];

  // Default categories
  static const List<String> defaultCategories = [
    'Food',
    'Transport',
    'Shopping',
    'Health',
    'Fun',
    'Rent',
    'EMI',
    'Others',
  ];

  // Notification IDs and channel
  static const int notifTransactionId = 1001;
  static const int notifDigestId = 1002;
  static const String notifChannelId = 'spendsense_channel';
  static const String notifChannelName = 'SpendSense Alerts';

  // Digest scheduler
  static const int digestHour = 21;
  static const int digestMinute = 0;
  static const String digestTimeZone = 'Asia/Kolkata';
}
