# SpendSense: Persistent AI Memory

## 1. Product Understanding
SpendSense is a **local-first, automation-driven expense manager** for the Indian market. It aims for a "zero-touch" UX by intercepting bank/UPI SMS messages and auto-categorizing them.
- **Core Value:** Privacy and automation.
- **Differentiator:** Operates without mandatory cloud accounts; AI is an optional enhancement.
- **Domain:** Currently focused on `EXPENSE` and `LOAN`.

## 2. Feature Summaries
- **SMS Orchestration:** Automated detection, filtering, and classification pipeline for incoming payment messages.
- **Hybrid Classification:** Uses a 4-tier waterfall:
    1. **Merchant Memory:** Exact-match history lookup.
    2. **Local Parser:** Regex-based extraction (HDFC, SBI, ICICI, AXIS).
    3. **AI Layer:** Optional LLM (Claude/Gemini) for high-entropy messages.
    4. **Manual Review:** Fallback for low-confidence or unknown patterns.
- **Review Systems:** Immediate popups (foreground) and a 9 PM daily digest (batch).
- **Voice Intelligence:** Short-form voice notes parsed by AI to categorize pending items.
- **Local Ledger:** Durable SQLite history with sync status tracking.
- **Best-effort Sync:** Google Sheets integration via Apps Script Webhook.

## 3. Architecture Understanding
- **Central Brain:** `lib/state/app_state.dart` (ChangeNotifier). Manages the end-to-end flow.
- **Local Source of Truth:** SQLite (`LocalStorageService`). Data is never lost even if sync fails.
- **Service Layer:** `lib/services/` contains single-responsibility services (SMS, Notification, AI, etc.).
- **Security:** `SecureStorageService` for credentials; SQLCipher planned for DB.
- **Classification Engine:** `SmsOrchestrator` & `AiService` (Provider-based).

## 4. Navigation Structure (Route Map)
- `/home`: Dashboard, Monthly Summary, Recent History, Pending Banner.
- `/setup`: Onboarding / Core Settings (API keys, Webhook).
- `/digest`: Batch review interface for pending transactions.
- `/popup`: Single-item quick-review (triggered via notifications).
- `/developer-tools`: Hidden debug menu for simulation and state wipes.

## 5. Design System Understanding
- **Framework:** Material 3 (Flutter).
- **Typography/Colors:** Standard Material defaults; Blue for verified, Amber for warnings (Learning Card).
- **Philosophy:** High-density data lists, prominent CTA buttons for review.
- **Key Component:** The **Learning Card** in `PopupScreen` – visualizes the app's "brain" and provides merchant feedback.

## 6. Current UX Problems
- **Notification Collisions:** Sequential transactions overwrite each other in the tray (shared ID).
- **Blocking Sync:** The UI hangs during batch confirmation in the Digest if the network is slow.
- **Invisible Sync:** No real-time indicator of sync progress or "stale" cloud state.
- **Generic ID Fatigue:** Users must repeatedly confirm bank-global headers (e.g., `AX-SBIUPI`) if not using AI.

## 7. Technical Constraints
- **Android Background Isolates:** Background SMS handlers have limited lifecycle; heavy DB/AI work must be handled carefully.
- **SMS Broadcast Receiver:** Android 11+ requires explicit manifest registration for background reliability.
- **Non-Idempotent Sync:** Append-only Sheets logic creates duplicates on retry without client-side ID checking.
- **Single-Account Focus:** Domain models don't yet support multi-account tracking or transfers.

## 8. Modernization Opportunities
- **Product Roadmap:** Deep analysis of growth and premium opportunities documented in `ai_context/FEATURE_IDEAS.md`.
- **SPEND-009:** OAuth 2.0 Native Google Sheets integration (replaces fragile Webhooks).
- **SPEND-001:** Expanding domain to support `INCOME` and `REFUND`.
- **Deduplication:** Move from body-hashing to structured UTR/Ref ID extraction.
- **Refactoring:** Decomposing `AppState` into specific Use Case classes (Clean Architecture).
- **On-Device AI:** Exploring Gemini Nano for local classification without API costs.

## 9. Core Development Rules
- **Rule 1:** SQLite Write FIRST. Sync SECOND.
- **Rule 2:** Never hardcode secrets. Use `SecureStorageService`.
- **Rule 3:** All logic must have reproduction tests in `test/`.
- **Rule 4:** Respect the "Council of Agents" audit findings (documented in `dsm_logs`).
