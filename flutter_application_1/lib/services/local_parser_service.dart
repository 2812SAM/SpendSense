import '../core/constants.dart';

class LocalParserResult {
  final double amount;
  final String merchant;
  final String category;
  final String type;
  final String confidence;

  LocalParserResult({
    required this.amount,
    required this.merchant,
    required this.category,
    this.type = AppConstants.typeExpense,
    this.confidence = AppConstants.confidenceHigh,
  });
}

class LocalParserService {
  LocalParserService._();
  static final LocalParserService instance = LocalParserService._();

  // STAGE 1: Hardened Bank-Specific Patterns (Anchored)
  // Based on high-confidence bank SMS structures.
  static final List<Map<String, dynamic>> _bankPatterns = [
    {
      'name': 'HDFC',
      'regex': RegExp(r'(?:Rs\.?|INR)\s?([\d,]+\.?\d*)\s?at\s?(.*?)\son',
          caseSensitive: false),
    },
    {
      'name': 'ICICI',
      'regex': RegExp(r'(?:Rs\.?|INR)\s?([\d,]+\.?\d*)\s?on.*?Info:\s?([^.]+)',
          caseSensitive: false),
    },
    {
      'name': 'SBI',
      'regex': RegExp(r'(?:Rs\.?|INR)\s?([\d,]+\.?\d*)\son.*?to\s?([^.]+)',
          caseSensitive: false),
    },
    {
      'name': 'Axis',
      'regex': RegExp(
          r'(?:Rs\.?|INR)\s?([\d,]+\.?\d*)\sdebited.*?for\s?UPI/P2M/([^/]+)/',
          caseSensitive: false),
    },
  ];

  // STAGE 2: Generic Debit/Spent Patterns (Waterfall fallback)
  static final List<Map<String, dynamic>> _genericPatterns = [
    {
      'name': 'Standard Debit',
      'regex': RegExp(
          r'(?:spent|paid|debited)\s?(?:Rs\.?|INR|₹)?\s?([\d,]+\.?\d*)\s(?:at|to|for)\s?(.*?)(?:\s(?:for|on|towards)\s|\.|\s$|$)',
          caseSensitive: false),
    },
    {
      'name': 'Sent To Person/Merchant',
      'regex': RegExp(
          r'sent\s?(?:Rs\.?|INR|₹)?\s?([\d,]+\.?\d*)\sto\s?(.*?)(?:\s(?:for|on|towards)\s|\.|\s$|$)',
          caseSensitive: false),
    },
  ];

  // Global Merchant Keyword Dictionary for Auto-Categorization
  static final Map<String, String> _merchantCategories = {
    'zomato': 'Food',
    'swiggy': 'Food',
    'uber': 'Transport',
    'ola': 'Transport',
    'amazon': 'Shopping',
    'flipkart': 'Shopping',
    'jio': 'Bills',
    'airtel': 'Bills',
    'vi ': 'Bills',
    'netflix': 'Entertainment',
    'spotify': 'Entertainment',
    'blinkit': 'Food',
    'zepto': 'Food',
    'starbucks': 'Food',
  };

  LocalParserResult? parse(String smsBody) {
    final lowerBody = smsBody.toLowerCase();

    // TIER 1: Exclusion Check (Negative Filter)
    // Fail fast on obvious non-expense items.
    for (final exc in AppConstants.smsExclusionKeywords) {
      if (lowerBody.contains(exc)) {
        return null;
      }
    }

    // TIER 2: Bank Specific Waterfall
    for (var p in _bankPatterns) {
      final match = (p['regex'] as RegExp).firstMatch(smsBody);
      if (match != null) {
        return _buildResult(match, p['name']);
      }
    }

    // TIER 3: Generic Waterfall
    for (var p in _genericPatterns) {
      final match = (p['regex'] as RegExp).firstMatch(smsBody);
      if (match != null) {
        return _buildResult(match, p['name'], isGeneric: true);
      }
    }

    return null;
  }

  LocalParserResult _buildResult(Match match, String patternName,
      {bool isGeneric = false}) {
    final amountStr = match.group(1)?.replaceAll(',', '') ?? '0';
    final amount = double.tryParse(amountStr) ?? 0.0;
    final rawMerchant = match.group(2)?.trim() ?? 'Unknown';

    final cleanMerchant = _cleanMerchantName(rawMerchant);

    // Try to categorize based on merchant keywords
    var category = 'Others';
    final lowerMerchant = cleanMerchant.toLowerCase();
    for (final entry in _merchantCategories.entries) {
      if (lowerMerchant.contains(entry.key)) {
        category = entry.value;
        break;
      }
    }

    return LocalParserResult(
      amount: amount,
      merchant: cleanMerchant,
      category: category,
      confidence:
          isGeneric ? AppConstants.confidenceLow : AppConstants.confidenceHigh,
    );
  }

  String _cleanMerchantName(String raw) {
    var clean = raw;

    // 1. Remove technical prefixes
    clean = clean.replaceAll(RegExp(r'^(?:VPS\*|UPI/P2M/|VPA:)'), '');

    // 2. Remove common transaction noise / reference numbers
    // Usually anything after a slash or long string of digits is noise
    // But be careful not to cut too early if there's no noise
    if (clean.contains('/')) {
      clean = clean.split('/')[0].trim();
    }

    // Check for long strings of digits (TXN IDs) and remove them
    clean = clean.replaceAll(RegExp(r'\b\d{10,}\b'), '').trim();

    // 3. Remove trailing dots/punctuation
    clean = clean.replaceAll(RegExp(r'[.\s]+$'), '');

    return clean;
  }
}
