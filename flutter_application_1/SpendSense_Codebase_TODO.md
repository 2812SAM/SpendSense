# SpendSense Codebase TODO

Last reviewed: 2026-04-19

## Current Stage: "Zero-Hurdle" Pivot
SpendSense is pivoting from a **Cloud-First (Claude/Sheets)** requirement to a **Local-First (Regex/SQLite)** by default model to reduce onboarding friction.

## Highest Priority TODOs (P0) - Core Stability & Zero-Hurdle

- [x] **Bypass Setup Screen on First Run.**
- [x] **Implement `LocalParserService` for Bank SMS.**
- [x] **Add required Android permissions to the manifest.**
- [x] **Persist ALL transactions locally first.**
- [x] **Implement Secure Storage for secrets.**
- [x] **100% Unit Test coverage for Local Parser.**
- [x] **Deterministic Deduplication (Fingerprinting).**
  Impact: Prevent duplicate entries from the same SMS. (Logic implemented using high-resolution SHA-256 hashing; verified via unit tests and simulation).

## P1 Priority - Professionalism & Connectivity

- [ ] **Google Sign-In Integration.**
  Goal: Replace manual Apps Script setup with a one-tap connection using the official Google Drive/Sheets API.
- [ ] **Initial Inbox Scan.**
  Impact: On first launch, scan the last 20 payment SMS messages to provide immediate value/data to the user.
- [ ] **Background Task Reliability (WorkManager).**
  Impact: Use `workmanager` to ensure SMS processing and sync retries happen even when the app is killed.
- [ ] **Error Reporting (Sentry).**
  Impact: Integrate Sentry to catch and log production crashes automatically.
- [ ] **Permission Guide UI.**
  Impact: If permissions are denied, show a helpful "How to enable" guide on the Home Screen.
- [x] **Dependency Injection (Refactor).**
  Impact: Initial refactor for `AppState` and `SecureStorageService` complete to enable high-fidelity mocking.
- [ ] **Dependency Injection (Full Coverage).**
  Impact: Complete refactor for `SheetsService` and `ClaudeService` to allow 100% cloud-free integration testing.
- [ ] **Automated CI/CD (GitHub Actions).**
  Impact: Automatically run `flutter analyze` and `flutter test` on every push to ensure code quality.

## P2 Priority - UX and Reliability

- [ ] **UI Transaction Grouping/Aggregation.**
  Impact: Group multiple transactions from the same merchant (e.g., 10 Swiggy orders) into a single expandable UI element on the Home screen to reduce clutter.
- [ ] **On-Device AI Exploration (Gemini Nano).**
  Goal: Research using Google AI Edge for 100% local, high-accuracy classification without API keys.
- [ ] **Fix Home Screen Live Updates.**
  Impact: Ensure feed refreshes automatically via `StreamBuilder` when transactions are confirmed.
- [ ] **Database Encryption (SQLCipher).**
  Impact: Protect the local SQLite file with AES-256 encryption.

## Current Architecture: FULL LOCAL LEDGER
The decision has been made: **SQLite is the primary source of truth.**
- Every transaction (AI, Regex, or Manual) is stored in the `transactions` table.
- `sync_status` tracks cloud state (`pending`, `synced`, `failed`).
- Home screen and summaries read exclusively from SQLite.
- Google Sheets is an append-only reporting destination.

## Build Order (Refined)
1. **Permission/Manifest Fixes** (Foundation).
2. **Setup Screen Bypass** (UX Quick Win).
3. **Local Regex Parser** (Replacing mandatory AI).
4. **Deduplication Logic** (Reliability).
5. **Background Workmanager for Digest** (Reliability).
6. **Optional AI/Cloud Toggle in Settings**.
gest** (Reliability).
6. **Optional AI/Cloud Toggle in Settings**.
bility).
6. **Optional AI/Cloud Toggle in Settings**.
gest** (Reliability).
6. **Optional AI/Cloud Toggle in Settings**.
