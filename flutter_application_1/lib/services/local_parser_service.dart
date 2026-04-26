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

  // Common Indian Bank SMS Patterns
  static final List<Map<String, dynamic>> _patterns = [
    {
      'name': 'ICICI V2',
      'regex': RegExp(
          r'(?:Rs\.?|INR)\s?([0-9,]+\.?[0-9]*)\s(?:debited|spent).*?for\s?([^.]+?)\.',
          caseSensitive: false),
    },
    {
      'name': 'HDFC',
      'regex': RegExp(r'Rs\.?\s?([0-9,]+\.?[0-9]*)\s?at\s?(.*?)(?:\.|\son)',
          caseSensitive: false),
    },
    {
      'name': 'ICICI',
      'regex': RegExp(
          r'INR\s?([0-9,]+\.?[0-9]*)\s?on.*?Info:\s?(.*?)\.?(?:\s|$)',
          caseSensitive: false),
    },
    {
      'name': 'SBI',
      'regex': RegExp(
          r'Transaction of Rs\.\s?([0-9,]+\.?[0-9]*)\son.*?to\s?(.*?)\.?(?:\s|$)',
          caseSensitive: false),
    },
    {
      'name': 'Axis',
      'regex': RegExp(
          r'INR\s?([0-9,]+\.?[0-9]*)\sdebited.*?for\s?UPI/P2M/(.*?)/',
          caseSensitive: false),
    },
  ];

  // Global Merchant Keyword Dictionary
  static final Map<String, String> _merchantCategories = {
    'zomato': 'Food',
    'swiggy': 'Food',
    'uber': 'Travel',
    'ola': 'Travel',
    'amazon': 'Shopping',
    'flipkart': 'Shopping',
    'jio': 'Bills',
    'airtel': 'Bills',
    'vi ': 'Bills',
    'netflix': 'Entertainment',
    'spotify': 'Entertainment',
  };

  LocalParserResult? parse(String smsBody) {
    for (var p in _patterns) {
      final match = (p['regex'] as RegExp).firstMatch(smsBody);
      if (match != null) {
        final amountStr = match.group(1)?.replaceAll(',', '') ?? '0';
        final amount = double.tryParse(amountStr) ?? 0.0;
        final rawMerchant = match.group(2)?.trim() ?? 'Unknown';

        // Try to categorize based on merchant keywords
        var category = 'Others';
        final lowerMerchant = rawMerchant.toLowerCase();
        for (final entry in _merchantCategories.entries) {
          if (lowerMerchant.contains(entry.key)) {
            category = entry.value;
            break;
          }
        }

        return LocalParserResult(
          amount: amount,
          merchant: rawMerchant,
          category: category,
        );
      }
    }

    return null;
  }
}
