/// SpendSense - Contact service.
/// Maps phone numbers to contact names for better context.

import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class ContactService {
  ContactService._();
  static final ContactService instance = ContactService._();

  // Cache to avoid repeated contact fetching
  final Map<String, String> _numberToNameCache = {};
  bool _isInitialised = false;

  /// Initialises the contact service by requesting permissions and warming the cache.
  Future<void> initialise() async {
    try {
      if (await FlutterContacts.requestPermission()) {
        _isInitialised = true;
        // Warm the cache with a few contacts or just rely on lazy loading
        await _refreshCache();
      }
    } catch (e) {
      debugPrint('SpendSense: Contact service failed to initialise: $e');
    }
  }

  /// Resolves a phone number to a contact name if available.
  /// Handles various number formats (with/without +91, spaces, etc.)
  Future<String?> resolveName(String phoneNumber) async {
    if (!_isInitialised) return null;

    final normalisedNumber = _normalisePhoneNumber(phoneNumber);
    if (_numberToNameCache.containsKey(normalisedNumber)) {
      return _numberToNameCache[normalisedNumber];
    }

    // Lazy load: fetch the specific contact
    try {
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      for (final contact in contacts) {
        for (final phone in contact.phones) {
          if (_normalisePhoneNumber(phone.number) == normalisedNumber) {
            final name = contact.displayName;
            _numberToNameCache[normalisedNumber] = name;
            return name;
          }
        }
      }
    } catch (e) {
      debugPrint('SpendSense: Error resolving contact: $e');
    }

    return null;
  }

  /// Normalises phone numbers by removing all non-digit characters except for the leading plus.
  String _normalisePhoneNumber(String phone) {
    // Remove all non-digit characters except '+'
    final res = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // For Indian numbers, if it starts with '91' but no '+', add it or handle it.
    // If it's a 10 digit number, it's likely local.
    if (res.length == 10 && !res.startsWith('+')) {
      return '+91$res';
    }
    if (res.startsWith('91') && res.length == 12 && !res.startsWith('+')) {
      return '+$res';
    }

    return res;
  }

  /// Periodically refreshes the entire contact cache.
  Future<void> _refreshCache() async {
    if (!_isInitialised) return;

    try {
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      for (final contact in contacts) {
        for (final phone in contact.phones) {
          final normalised = _normalisePhoneNumber(phone.number);
          _numberToNameCache[normalised] = contact.displayName;
        }
      }
    } catch (e) {
      debugPrint('SpendSense: Error refreshing contact cache: $e');
    }
  }
}
