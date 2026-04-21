# SpendSense: Gemini Instructional Context

SpendSense is a local-first, AI-powered expense tracker for Android that automates transaction logging from UPI and bank SMS messages. It uses the Claude API for categorization and syncs data to Google Sheets via a Google Apps Script webhook.

## Project Overview

- **Core Purpose:** Provide a "zero-touch" expense tracking experience for Indian UPI users by capturing transaction data directly from SMS.
- **Main Technologies:**
    - **Frontend:** Flutter (Dart) for Android.
    - **Local Database:** SQLite (`sqflite`) for a local-first transaction ledger and merchant memory.
    - **AI Engine:** Anthropic Claude API for transaction categorization and voice note interpretation.
    - **Backend:** Google Apps Script (JavaScript) for syncing to Google Sheets.
    - **Integrations:** `telephony` for SMS ingestion, `flutter_local_notifications` for review prompts, `speech_to_text` for voice confirmation.
- **Architecture:** 
    - **Local-First:** All transactions are persisted to a local SQLite ledger *before* or alongside sync attempts.
    - **Event-Driven:** SMS receipt triggers an orchestration flow in `AppState`.
    - **Manual Review:** Low-confidence classifications trigger immediate notifications (popups) or are held for a daily 9 PM digest.

## Key Files & Directories

- `lib/state/app_state.dart`: The central "brain" of the app. Manages the end-to-end flow from SMS receipt to ledger persistence and cloud sync.
- `lib/services/local_storage_service.dart`: Manages the SQLite database, including the `transactions` ledger and `merchant_memory`.
- `lib/services/sms_service.dart`: Handles SMS permissions and background/foreground message ingestion.
- `lib/services/claude_service.dart`: Encapsulates all calls to the Anthropic API for classification and voice processing.
- `lib/services/notification_service.dart`: Manages transaction-specific popups and the scheduled daily digest.
- `lib/services/sheets_service.dart`: Handles the outbound sync to the Google Apps Script webhook.
- `backend/apps_script.js`: The server-side code deployed to Google Apps Script to update Google Sheets.
- `lib/models/transaction.dart`: The primary `MyTransaction` data model.

## Building and Running

### Prerequisites
1.  **Flutter SDK:** Ensure Flutter is installed and configured for Android development.
2.  **Android Device:** A physical Android device is required for SMS ingestion and notification features.
3.  **Claude API Key:** An active API key from Anthropic.
4.  **Google Sheets Setup:** 
    - Create a Google Sheet with `Expenses` and `Loans` tabs.
    - Deploy `backend/apps_script.js` as a Web App (set access to "Anyone").

### Commands
- **Install Dependencies:** `flutter pub get`
- **Run App:** `flutter run` (Ensure a real Android device is connected).
- **Build APK:** `flutter build apk`
- **Tests:** `flutter test`

## Development Conventions

### Architectural Mandates
1.  **Local-First Integrity:** Every transaction MUST be written to the local SQLite ledger (`LocalStorageService`) before any sync attempt.
2.  **Centralized Orchestration:** All business logic for transaction lifecycles (received -> classified -> confirmed -> synced) should reside in `AppState.dart`.
3.  **Merchant Learning:** Merchant memory (`merchant_memory` table) should only be updated upon explicit user confirmation (manual or voice) to maintain high data quality.
4.  **Graceful Degradation:** If the Claude API is unavailable or returns low confidence, the app must fallback to a manual review state (`is_confirmed = false`, `needs_user_input = true`) rather than failing or dropping data.

### Coding Standards
- **Immutability:** Use `copyWith` on models (`MyTransaction`, `MerchantMemory`) instead of direct mutation.
- **Service Pattern:** Keep external integrations (SMS, AI, Sheets) isolated in the `lib/services/` directory.
- **Error Handling:** Use the `TxState` enum in `AppState` to track and display the status of transaction processing.
- **Linting:** Adhere to standard Flutter lints; one exception exists in `analysis_options.yaml` for library doc comments.

## Roadmap & Known Gaps (Alpha Stage)
- **Deduplication:** The app currently lacks a deterministic deduplication strategy for identical SMS messages.
- **Idempotency:** The Google Sheets sync is append-only; retries can result in duplicate rows in the sheet.
- **Domain Scope:** Currently optimized for `EXPENSE` and `LOAN` types; `INCOME` and `REFUND` are not yet first-class types.
- **Testing:** Automated test coverage is minimal; priority should be given to `AppState` and `LocalStorageService` unit tests.

## Future Context
For a deeper dive into the architecture, edge cases, and component responsibilities, refer to `flutter_application_1/SpendSense_Repository_Context.md`.
