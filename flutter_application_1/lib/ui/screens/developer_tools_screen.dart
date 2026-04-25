import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/debug_samples.dart';
import '../../services/local_storage_service.dart';
import '../../services/sheets_service.dart';
import '../../state/app_state.dart';

class DeveloperToolsScreen extends StatefulWidget {
  const DeveloperToolsScreen({super.key});

  @override
  State<DeveloperToolsScreen> createState() => _DeveloperToolsScreenState();
}

class _DeveloperToolsScreenState extends State<DeveloperToolsScreen> {
  bool _forceSyncFail = SheetsService.instance.debugForceFail;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const Scaffold(body: Center(child: Text('Debug mode only')));
    }

    final appState = Provider.of<AppState>(context, listen: false);

    String makeUnique(String sms) =>
        '$sms | salt: ${DateTime.now().millisecondsSinceEpoch}';

    return Scaffold(
      appBar: AppBar(title: const Text('Developer Tools')),
      body: ListView(
        children: [
          _buildSection('SMS Injection Simulation'),
          _buildAction('Simulate HDFC (Rs 100)', () {
            // ignore: invalid_use_of_visible_for_testing_member
            appState.onPaymentSmsReceived(
                makeUnique(DebugSamples.hdfc), 'AD-HDFCBK');
          }),
          _buildAction('Simulate ICICI (Rs 1250)', () {
            // ignore: invalid_use_of_visible_for_testing_member
            appState.onPaymentSmsReceived(
                makeUnique(DebugSamples.icici), 'VM-ICICIB');
          }),
          _buildAction('Simulate SBI (Rs 200)', () {
            // ignore: invalid_use_of_visible_for_testing_member
            appState.onPaymentSmsReceived(
                makeUnique(DebugSamples.sbi), 'AX-SBIUPI');
          }),
          _buildAction('Simulate Axis (Rs 350)', () {
            // ignore: invalid_use_of_visible_for_testing_member
            appState.onPaymentSmsReceived(
                makeUnique(DebugSamples.axis), 'AX-AXISBK');
          }),
          _buildAction('Simulate Unknown (Manual Review)', () {
            // ignore: invalid_use_of_visible_for_testing_member
            appState.onPaymentSmsReceived(
                makeUnique(DebugSamples.unknown), 'UNKNOWN');
          }),
          _buildAction('Simulate EXACT Duplicate (HDFC)', () {
            // No salt added, tests deduplication and Merchant Memory
            // ignore: invalid_use_of_visible_for_testing_member
            appState.onPaymentSmsReceived(DebugSamples.hdfc, 'AD-HDFCBK');
          }),
          _buildAction('Simulate EXACT Unknown (No Salt)', () {
            // No salt, tests memory fallback and deduplication
            // ignore: invalid_use_of_visible_for_testing_member
            appState.onPaymentSmsReceived(DebugSamples.unknown, 'UNKNOWN');
          }),
          _buildSection('Sync Configuration'),
          SwitchListTile(
            title: const Text('Force Sync Failure'),
            subtitle: const Text('Simulates network/webhook errors'),
            value: _forceSyncFail,
            onChanged: (val) {
              setState(() {
                _forceSyncFail = val;
                SheetsService.instance.debugForceFail = val;
              });
            },
          ),
          _buildSection('Database Management'),
          _buildAction('Clear All Transactions', () async {
            final messenger = ScaffoldMessenger.of(context);
            await LocalStorageService.instance.debugClearAll();
            messenger.showSnackBar(
              const SnackBar(content: Text('Database wiped.')),
            );
          }, color: Colors.red),
          const SizedBox(height: 40),
          const Center(
            child: Text(
              'These tools are only available in debug builds.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.blueAccent,
        ),
      ),
    );
  }

  Widget _buildAction(String label, VoidCallback onTap, {Color? color}) {
    return ListTile(
      title: Text(label, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }
}
