import 'package:flutter/material.dart';
import '../../services/local_storage_service.dart';
import '../../core/constants.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  List<Map<String, dynamic>> _customCategories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await LocalStorageService.instance.getCustomCategories();
    if (mounted) {
      setState(() {
        _customCategories = categories;
        _loading = false;
      });
    }
  }

  void _showEditDialog({String? oldName, String? oldEmoji, String? oldDesc}) {
    final nameController = TextEditingController(text: oldName);
    final emojiController = TextEditingController(text: oldEmoji ?? '🏷️');
    final descController = TextEditingController(text: oldDesc);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(oldName == null ? 'New Category' : 'Edit Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Category Name'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emojiController,
              decoration: const InputDecoration(labelText: 'Emoji'),
              maxLength: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description (For AI Insights)',
                hintText: 'e.g. Steam games, concerts',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final newName = nameController.text.trim();
              final newEmoji = emojiController.text.trim();
              final newDesc = descController.text.trim();
              if (newName.isEmpty) return;

              if (oldName == null) {
                await LocalStorageService.instance
                    .saveCustomCategory(newName, emoji: newEmoji);
              } else {
                await LocalStorageService.instance
                    .renameCategory(oldName, newName, newEmoji: newEmoji);
              }

              if (newDesc.isNotEmpty) {
                await LocalStorageService.instance
                    .saveCategoryMetadata(newName, newDesc);
              }

              navigator.pop();
              await _loadCategories();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(String name) async {
    final targetCategory = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text('"$name" has transactions. Reassign them to:'),
        actions: [
          ...AppConstants.defaultCategories.map((cat) => TextButton(
                onPressed: () => Navigator.pop(context, cat),
                child: Text(cat),
              )),
        ],
      ),
    );

    if (targetCategory != null) {
      await LocalStorageService.instance
          .reassignAndExcludeCategory(name, targetCategory);
      await _loadCategories();
    }
  }

  @override
  Widget build(BuildContext context) {
    final allCategories = [
      ...AppConstants.defaultCategories.map((cat) => {
            'name': cat,
            'emoji': _getSystemEmoji(cat),
            'isSystem': true,
            'description': null
          }),
      ..._customCategories.map((cat) => {...cat, 'isSystem': false}),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: allCategories.length,
              itemBuilder: (context, index) {
                final cat = allCategories[index];
                final isSystem = cat['isSystem'] as bool;
                final name = cat['name'] as String;
                final emoji = cat['emoji'] as String;
                final desc = cat['description'] as String?;

                return ListTile(
                  leading: Text(emoji, style: const TextStyle(fontSize: 24)),
                  title: Text(name),
                  subtitle: isSystem
                      ? const Text('System Category',
                          style: TextStyle(fontSize: 12))
                      : Text(
                          desc != null && desc.isNotEmpty
                              ? desc
                              : 'Custom Category',
                          style: const TextStyle(fontSize: 12)),
                  trailing: isSystem
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _showEditDialog(
                                  oldName: name,
                                  oldEmoji: emoji,
                                  oldDesc: desc),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () async {
                                try {
                                  await LocalStorageService.instance
                                      .deleteCategory(name);
                                  await _loadCategories();
                                } catch (e) {
                                  await _confirmDelete(name);
                                }
                              },
                            ),
                          ],
                        ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _getSystemEmoji(String category) {
    const emojis = {
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
    return emojis[category] ?? '🏷️';
  }
}
