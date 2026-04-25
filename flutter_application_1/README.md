# SpendSense

SpendSense is a zero-touch, privacy-first expense tracker for Indian UPI users.

**Current Philosophy:** Local-First, Zero-Hurdle. The app works instantly upon installation without requiring any API keys or cloud setup.

## Core Features

- **Instant Automation:** Captures expenses from SMS immediately after granting permissions.
- **Local-First Ledger:** All transactions are stored in a private SQLite database on your phone.
- **Merchant Learning:** Differentiates between shops (Static) and friends (Dynamic) to ensure accurate personal tracking.
- **Custom Categories:** Create and manage your own spending labels that integrate with AI and local storage.
- **Secure by Design:** API keys and sensitive URLs are stored in encrypted system storage (Keychain/Keystore) via `SecureStorageService`.
- **Logic Verified:** Core data services, UI components, and AI logic are protected by a comprehensive automated test suite (Unit, Widget, and E2E journeys).
- **Developer Ready:** Hidden internal debug menu to simulate transactions and test sync reliability.
- **Automatic Deduplication:** Uses strict SHA-256 body-hashing to prevent duplicate transaction entries from network retries.
- **Smart Learning Memory:** Remembers categorization choices with **Generic ID Protection** to prevent accidental global auto-categorization for bank headers.
- **Optional AI Power:** Connect a Claude API key for high-accuracy categorization of complex messages.
- **Optional Cloud Sync:** Connect to Google Sheets via a simple "Sign in with Google" (planned) or manual Webhook for permanent backups.

## Core Flow

1. **SMS Arrival:** Payment SMS arrives on the phone.
2. **Local Parsing:** App extracts amount and merchant using local regex and keywords.
3. **Merchant Memory:** Checks if you've categorized this merchant before.
4. **AI Fallback (Optional):** If configured, unknown transactions go to Claude for categorization.
5. **Local Persistence:** Every transaction is saved into the local SQLite ledger immediately.
6. **Review Flow:** Low-confidence transactions trigger a confirmation popup or daily digest.
7. **Cloud Sync (Optional):** High-confidence or confirmed transactions sync to Google Sheets if configured.

## Getting Started (Local-Only)

1. Run `flutter pub get`.
2. Run the app on a real Android device.
3. Grant SMS and Notification permissions.
4. **Start tracking immediately.** No keys required.

## Advanced Setup (Optional)

1. **AI Categorization:** Get a Claude API key from Anthropic and add it in Settings for better accuracy.
2. **Cloud Backup:** Deploy the `backend/apps_script.js` and add the Webhook URL in Settings to sync with Google Sheets.

## Important Files

- `lib/state/app_state.dart`: Central orchestration logic.
- `lib/services/local_storage_service.dart`: The SQLite "Source of Truth."
- `lib/services/local_parser_service.dart`: Regex-based local SMS parsing logic.
- `lib/services/secure_storage_service.dart`: Encrypted storage for secrets.
- `lib/services/sms_service.dart`: SMS ingestion and background processing.
- `lib/services/claude_service.dart`: Optional AI integration.
- `lib/ui/screens/setup_screen.dart`: Settings for optional AI and Cloud features.

