/// SpendSense - Setup / settings screen.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';
import '../../services/claude_service.dart';
import '../../services/sheets_service.dart';
import '../../services/secure_storage_service.dart';

class SetupScreen extends StatefulWidget {
  final bool isOnboarding;

  const SetupScreen({super.key, this.isOnboarding = false});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _apiKeyCtrl = TextEditingController();
  final _webhookCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isTestingApi = false;
  bool _isTestingWebhook = false;
  bool _apiKeyOk = false;
  bool _webhookOk = false;
  bool _isSaving = false;
  String? _apiTestError;
  String? _webhookTestError;
  String? _lastValidatedApiKey;
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

    _apiKeyCtrl.text =
        await secure.readSecret(AppConstants.prefClaudeApiKey) ?? '';
    _webhookCtrl.text =
        await secure.readSecret(AppConstants.prefWebhookUrl) ?? '';

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _webhookCtrl.dispose();
    super.dispose();
  }

  Future<bool> _testApiKey() async {
    final apiKey = _apiKeyCtrl.text.trim();
    if (apiKey.isEmpty) {
      setState(() => _apiTestError = 'Enter the API key first');
      return false;
    }

    setState(() {
      _isTestingApi = true;
      _apiTestError = null;
      _apiKeyOk = false;
    });

    final ok = await ClaudeService.instance.testApiKey(apiKey);

    if (!mounted) return ok;
    setState(() {
      _isTestingApi = false;
      _apiKeyOk = ok;
      _apiTestError =
          ok ? null : 'Claude API test failed - check the key and billing';
      _lastValidatedApiKey = ok ? apiKey : null;
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

    final apiKey = _apiKeyCtrl.text.trim();
    final webhook = _webhookCtrl.text.trim();

    // Only test if not empty
    if (apiKey.isNotEmpty) {
      final apiOk = _apiKeyOk && _lastValidatedApiKey == apiKey
          ? true
          : await _testApiKey();
      if (!apiOk) {
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

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefClaudeApiKey, apiKey);
    await prefs.setString(AppConstants.prefWebhookUrl, webhook);
    await prefs.remove(AppConstants.legacyPrefWebhookUrl);
    await prefs.setBool(AppConstants.prefOnboardingDone, true);

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (widget.isOnboarding) {
      // ignore: unawaited_futures
      Navigator.of(context).pushReplacementNamed('/home');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('Settings saved')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                  title: 'Claude AI (Optional)',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enable high-accuracy categorization for complex SMS. Get your key from console.anthropic.com.',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _apiKeyCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: 'Enter Claude API Key (Optional)',
                          border: OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: Icon(Icons.vpn_key_outlined, size: 18),
                        ),
                        onChanged: (_) {
                          setState(() {
                            _apiKeyOk = false;
                            _lastValidatedApiKey = null;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
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
                            label: Text(
                                _isTestingApi ? 'Testing...' : 'Test Claude'),
                          ),
                          const SizedBox(width: 10),
                          if (_apiKeyOk)
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
