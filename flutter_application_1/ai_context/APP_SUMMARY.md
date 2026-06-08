# SpendSense Application Summary

## 1. App Purpose Summary
SpendSense is a local-first, privacy-focused expense management application designed to automate transaction logging for Indian users. It captures financial data directly from bank and UPI SMS messages, using a combination of local regex parsing and optional AI classification to categorize expenses without requiring manual entry.

## 2. Target Audience
- **Primary:** Indian UPI users (Google Pay, PhonePe, Paytm, etc.) who receive frequent bank SMS notifications.
- **Secondary:** Users seeking a "zero-touch" expense tracking experience that prioritizes privacy and local data storage over cloud-required alternatives.

## 3. Core Feature List
- **Automated SMS Ingestion:** Real-time capture of payment SMS via a background listener.
- **Hybrid Categorization:** 
    - **Local Parser:** Regex-based extraction for common Indian banks (HDFC, SBI, ICICI, AXIS).
    - **Merchant Memory:** Learns and remembers categories from user-confirmed merchants.
    - **Optional AI:** Provider-based integration (Claude/Gemini) for complex or ambiguous messages.
- **Local-First Ledger:** Full SQLite database (`sqflite`) acting as the primary source of truth.
- **Review Flows:** Immediate popup notifications for low-confidence hits and a scheduled 9 PM daily digest.
- **Voice Confirmation:** Natural language disambiguation for pending transactions.
- **Cloud Sync:** Best-effort sync to Google Sheets (currently via Apps Script Webhook).
- **Security:** Encrypted storage for API keys and planned SQLCipher integration for the local ledger.

## 4. Architecture Summary
SpendSense follows a service-oriented architecture centered around a global state orchestrator:
- **AppState (`lib/state/app_state.dart`):** The central "brain" managing the lifecycle of a transaction from SMS receipt to ledger persistence.
- **Service Layer (`lib/services/`):** Isolated modules for storage, SMS, notifications, and AI.
- **Local-First Principle:** Every transaction is written to SQLite before any sync attempt.
- **Provider-Based AI:** Refactored `AiService` supporting multiple LLM backends (Claude, Gemini).
- **Flutter Framework:** Cross-platform (Android-primary) UI with a reactive `ChangeNotifier` state model.

## 5. User Flow Summary
1. **SMS Arrival:** Device receives a payment SMS.
2. **Detection:** `SmsService` filters for payment keywords; `SmsOrchestrator` triggers the pipeline.
3. **Classification:**
    - Match found in **Merchant Memory** -> Auto-confirm.
    - No match -> **Local Parser** (Regex) -> **AI** (if configured).
4. **Persistence:** Transaction saved to local SQLite with `sync_status = pending`.
5. **Review (if needed):** User receives a popup or daily digest reminder for low-confidence items.
6. **Sync:** Confirmed transactions are pushed to Google Sheets; failed syncs are retried on the next app launch.

## 6. Current UX Maturity Assessment
**Stage: Alpha (Functional Prototype)**
- **Pros:** Zero-touch automation works; local-first speed is high.
- **Cons:** Notification collisions (single ID usage); "Invisible sync" (lack of progress/health indicators); Setup screen is functional but utilitarian.
- **Overall:** Highly functional for developers/power users, but lacks the "emotional polish" and feedback loops required for a consumer-grade app.

## 7. Design Consistency Assessment
- **Architecture:** High consistency. The use of `AppState` and clear service boundaries is well-maintained.
- **UI:** Medium consistency. Standard Material components are used, but the visual language is basic.
- **State Management:** Consistent use of `ChangeNotifier` and `Provider`, though `AppState` is becoming a "God Object" that requires further decomposition.

## 8. Missing Product Areas
- **Full Ledger Coverage:** Currently lacks first-class support for `INCOME`, `REFUND`, and `REVERSAL` types.
- **Multi-Account Support:** Does not yet differentiate between multiple bank accounts/cards.
- **Onboarding UX:** Permissions are requested correctly, but a guided "how it works" tutorial is missing.
- **Privacy Center:** No in-app dashboard to view/delete data or manage data sharing preferences.

## 9. Current Technical Limitations
- **Android Background Delivery:** OS-level constraints on Android 11+ can delay or block SMS receipt if the app is killed (requires static `BroadcastReceiver` hardening).
- **Non-Idempotent Sync:** Duplicate retries to Google Sheets can result in duplicate rows (requires unique ID checking in Apps Script).
- **Sequential Sync:** Digest confirmation is currently blocked by sequential HTTP calls, causing UI lag during batch processing.
- **Deduplication:** Relies on body hashing; more robust UTR/Ref ID extraction is needed for 100% reliability across varied banks.
