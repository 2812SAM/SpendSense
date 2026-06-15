import '../../services/local_storage_service.dart';

class CategoryService {
  CategoryService._();
  static final CategoryService instance = CategoryService._();

  Map<String, String>? _cachedEmojis;

  Future<Map<String, String>> getAllCategoriesWithEmojis() async {
    final custom = await LocalStorageService.instance.getCustomCategories();

    final map = <String, String>{
      'Food': '🍕',
      'Transport': '🚗',
      'Shopping': '🛍',
      'Health': '💊',
      'Fun': '🎬',
      'Rent': '🏠',
      'EMI': '💳',
      'Loan': '💸',
      'Others': '📦',
    };

    for (final cat in custom) {
      map[cat['name'] as String] = cat['emoji'] as String;
    }

    _cachedEmojis = map;
    return map;
  }

  Future<String> getEmoji(String category) async {
    if (_cachedEmojis != null && _cachedEmojis!.containsKey(category)) {
      return _cachedEmojis![category]!;
    }

    final all = await getAllCategoriesWithEmojis();
    return all[category] ?? '🏷️';
  }

  void clearCache() {
    _cachedEmojis = null;
  }
}
