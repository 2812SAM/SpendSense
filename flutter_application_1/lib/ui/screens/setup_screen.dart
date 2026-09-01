/// SpendSense - Setup / settings screen.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';
import '../../services/ai_service.dart';
import '../../services/sheets_service.dart';
import '../../services/secure_storage_service.dart';

class SetupScreen extends StatefulWidget {
  final bool isOnboarding;

  const SetupScreen({super.key, this.isOnboarding = false});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _claudeKeyCtrl = TextEditingController();
  final _geminiKeyCtrl = TextEditingController();
  final _webhookCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _selectedProvider = 'claude';
  bool _isTestingApi = false;
  bool _isTestingWebhook = false;
  bool _claudeOk = false;
  bool _geminiOk = false;
  bool _webhookOk = false;
  bool _isSaving = false;
  String? _apiTestError;
  String? _webhookTestError;
  String? _lastValidatedClaudeKey;
  String? _lastValidatedGeminiKey;
  String? _lastValidatedWebhook;

  @override
  void initState() {
    super.initState();
    _loadSavedValues();
  }

  Future<void> _loadSavedValues() async {
    final secure = SecureStorageService.instance;

    // Attempt migration in case AppState hasn't run yet
    await secure.migrateFromPrefs();

    _selectedProvider =
        await secure.readSecret(AppConstants.prefAiProvider) ?? 'claude';
    _claudeKeyCtrl.text =
        await secure.readSecret(AppConstants.prefClaudeApiKey) ?? '';
    _geminiKeyCtrl.text =
        await secure.readSecret(AppConstants.prefGeminiApiKey) ?? '';
    _webhookCtrl.text =
        await secure.readSecret(AppConstants.prefWebhookUrl) ?? '';

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _claudeKeyCtrl.dispose();
    _geminiKeyCtrl.dispose();
    _webhookCtrl.dispose();
    super.dispose();
  }

  Future<bool> _testApiKey() async {
    final apiKey = _selectedProvider == 'gemini'
        ? _geminiKeyCtrl.text.trim()
        : _claudeKeyCtrl.text.trim();

    if (apiKey.isEmpty) {
      setState(() => _apiTestError = 'Enter the API key first');
      return false;
    }

    setState(() {
      _isTestingApi = true;
      _apiTestError = null;
      if (_selectedProvider == 'gemini') {
        _geminiOk = false;
      } else {
        _claudeOk = false;
      }
    });

    final ok = await AiService.instance.testApiKey(_selectedProvider, apiKey);

    if (!mounted) return ok;
    setState(() {
      _isTestingApi = false;
      if (_selectedProvider == 'gemini') {
        _geminiOk = ok;
        _lastValidatedGeminiKey = ok ? apiKey : null;
      } else {
        _claudeOk = ok;
        _lastValidatedClaudeKey = ok ? apiKey : null;
      }
      _apiTestError = ok
          ? null
          : '$_selectedProvider API test failed - check the key and billing';
    });
    return ok;
  }

  Future<bool> _testWebhook() async {
    final url = _webhookCtrl.text.trim();
    if (url.isEmpty) {
      setState(() => _webhookTestError = 'Enter the webhook URL first');
      return false;
    }

    setState(() {
      _isTestingWebhook = true;
      _webhookTestError = null;
      _webhookOk = false;
    });

    final ok = await SheetsService.instance.testWebhook(url);

    if (!mounted) return ok;
    setState(() {
      _isTestingWebhook = false;
      _webhookOk = ok;
      _webhookTestError = ok
          ? null
          : 'Webhook test failed - check URL and Apps Script deployment';
      _lastValidatedWebhook = ok ? url : null;
    });
    return ok;
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    final claudeKey = _claudeKeyCtrl.text.trim();
    final geminiKey = _geminiKeyCtrl.text.trim();
    final webhook = _webhookCtrl.text.trim();

    // Validate the ACTIVE provider's key if not empty
    if (_selectedProvider == 'claude' && claudeKey.isNotEmpty) {
      final ok = _claudeOk && _lastValidatedClaudeKey == claudeKey
          ? true
          : await _testApiKey();
      if (!ok) {
        if (mounted) setState(() => _isSaving = false);
        return;
      }
    } else if (_selectedProvider == 'gemini' && geminiKey.isNotEmpty) {
      final ok = _geminiOk && _lastValidatedGeminiKey == geminiKey
          ? true
          : await _testApiKey();
      if (!ok) {
        if (mounted) setState(() => _isSaving = false);
        return;
      }
    }

    if (webhook.isNotEmpty) {
      final webhookOk = _webhookOk && _lastValidatedWebhook == webhook
          ? true
          : await _testWebhook();
      if (!webhookOk) {
        if (mounted) setState(() => _isSaving = false);
        return;
      }
    }

    final secure = SecureStorageService.instance;
    await secure.saveSecret(AppConstants.prefAiProvider, _selectedProvider);
    await secure.saveSecret(AppConstants.prefClaudeApiKey, claudeKey);
    await secure.saveSecret(AppConstants.prefGeminiApiKey, geminiKey);
    await secure.saveSecret(AppConstants.prefWebhookUrl, webhook);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.legacyPrefWebhookUrl);
    await prefs.setBool(AppConstants.prefOnboardingDone, true);

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (widget.isOnboarding) {
      // ignore: unawaited_futures
      Navigator.of(context).pushReplacementNamed('/goals-settings');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('Settings saved')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: widget.isOnboarding
          ? null
          : AppBar(title: const Text('Setup'), centerTitle: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.isOnboarding) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'SpendSense',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Two things to set up. Takes 5 minutes.',
                    style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 36),
                ],
                _StepCard(
                  step: '1',
                  title: 'AI Engine (Optional)',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enable high-accuracy categorization for complex SMS.',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedProvider,
                        decoration: const InputDecoration(
                          labelText: 'Select AI Provider',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'claude',
                              child: Text('Claude (Anthropic)')),
                          DropdownMenuItem(
                              value: 'gemini', child: Text('Gemini (Google)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedProvider = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_selectedProvider == 'claude')
                        TextFormField(
                          controller: _claudeKeyCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            hintText: 'Enter Claude API Key',
                            labelText: 'Claude API Key',
                            border: OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: Icon(Icons.vpn_key_outlined, size: 18),
                          ),
                          onChanged: (_) => setState(() => _claudeOk = false),
                        )
                      else
                        TextFormField(
                          controller: _geminiKeyCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            hintText: 'Enter Gemini API Key',
                            labelText: 'Gemini API Key',
                            border: OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: Icon(Icons.vpn_key_outlined, size: 18),
                          ),
                          onChanged: (_) => setState(() => _geminiOk = false),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _isTestingApi ? null : _testApiKey,
                            icon: _isTestingApi
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.bolt, size: 16),
                            label: Text(_isTestingApi
                                ? 'Testing...'
                                : 'Test Connection'),
                          ),
                          const SizedBox(width: 10),
                          if ((_selectedProvider == 'claude' && _claudeOk) ||
                              (_selectedProvider == 'gemini' && _geminiOk))
                            const Row(
                              children: [
                                Icon(Icons.check_circle,
                                    color: Colors.green, size: 18),
                                SizedBox(width: 4),
                                Text(
                                  'Connected',
                                  style: TextStyle(
                                      color: Colors.green, fontSize: 13),
                                ),
                              ],
                            ),
                        ],
                      ),
                      if (_apiTestError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _apiTestError!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _StepCard(
                  step: '2',
                  title: 'Google Sheets Sync (Optional)',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Automatically backup your expenses to a spreadsheet. Deployment of the SpendSense Apps Script is required.',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _webhookCtrl,
                        decoration: const InputDecoration(
                          hintText: 'https://script.google.com/... (Optional)',
                          border: OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: Icon(Icons.link_outlined, size: 18),
                        ),
                        onChanged: (_) {
                          setState(() {
                            _webhookOk = false;
                            _lastValidatedWebhook = null;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _isTestingWebhook ? null : _testWebhook,
                            icon: _isTestingWebhook
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.bolt, size: 16),
                            label: Text(_isTestingWebhook
                                ? 'Testing...'
                                : 'Test webhook'),
                          ),
                          const SizedBox(width: 10),
                          if (_webhookOk)
                            const Row(
                              children: [
                                Icon(Icons.check_circle,
                                    color: Colors.green, size: 18),
                                SizedBox(width: 4),
                                Text(
                                  'Connected',
                                  style: TextStyle(
                                      color: Colors.green, fontSize: 13),
                                ),
                              ],
                            ),
                        ],
                      ),
                      if (_webhookTestError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _webhookTestError!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.bug_report_outlined,
                        color: Colors.orange),
                    title: const Text('Developer Options'),
                    subtitle:
                        const Text('Simulate SMS and test sync reliability'),
                    trailing: const Icon(Icons.chevron_right),
                    // ignore: unawaited_futures
                    onTap: () => Navigator.pushNamed(context, '/debug'),
                  ),
                ],
                if (!widget.isOnboarding) ...[
                  const SizedBox(height: 16),
                  _StepCard(
                    step: '3',
                    title: 'Spending Goals',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.track_changes_outlined),
                      title: const Text('Set Monthly Limits'),
                      subtitle: const Text(
                          'Adjust your overall and category targets'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          Navigator.pushNamed(context, '/goals-settings'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _StepCard(
                    step: '4',
                    title: 'Categorisation',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.category_outlined),
                      title: const Text('Manage Categories'),
                      subtitle: const Text('Add, rename or delete categories'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          Navigator.pushNamed(context, '/manage-categories'),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            widget.isOnboarding
                                ? 'Start tracking'
                                : 'Save settings',
                            style: const TextStyle(fontSize: 15),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: Colors.amber[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'SpendSense needs SMS, notification, and microphone permissions to work reliably.',
                          style:
                              TextStyle(fontSize: 12, color: Colors.amber[900]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String step;
  final String title;
  final Widget child;

  const _StepCard({
    required this.step,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  step,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
