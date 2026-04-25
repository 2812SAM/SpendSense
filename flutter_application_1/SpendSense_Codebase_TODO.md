# SpendSense Codebase TODO

Last reviewed: 2026-04-24

## Current Stage: "Zero-Hurdle" Pivot
SpendSense is pivoting from a **Cloud-First (Claude/Sheets)** requirement to a **Local-First (Regex/SQLite)** by default model to reduce onboarding friction.

## Highest Priority TODOs (P0) - Core Stability & Zero-Hurdle

- [x] **Bypass Setup Screen on First Run.**
- [x] **Implement `LocalParserService` for Bank SMS.**
- [x] **Add required Android permissions to the manifest.**
- [x] **Persist ALL transactions locally first.**
- [x] **Implement Secure Storage for secrets.**
- [x] **100% Unit Test coverage for Local Parser.**
- [x] **Verify core data logic with tests (>30% project coverage).**
- [x] **Strict SMS-Body Deduplication.**
  Impact: Replaced unreliable 15s window with strict SHA-256 body hashing for mathematical reliability.
- [x] **Establish Regression Test Suite.**
  Impact: 45+ tests including Unit, Widget (Learning Card), and E2E journeys.

## P1 Priority - Professionalism & Connectivity

- [ ] **Google Sign-In Integration.**
- [ ] **Initial Inbox Scan.**
- [ ] **Background Task Reliability (WorkManager).**
- [ ] **Foreground Auto-Popup.**
  Impact: Categorization popups now auto-open if the app is active, bypassing system notification suppression.
- [ ] **Error Reporting (Sentry).**
- [ ] **Permission Guide UI.**
- [x] **Dependency Injection (Refactor).**
- [ ] **Automated CI/CD (GitHub Actions).**

## P2 Priority - UX and Reliability

- [ ] **UI Transaction Grouping/Aggregation.**
- [ ] **On-Device AI Exploration (Gemini Nano).**
- [ ] **Fix Home Screen Live Updates.**
- [ ] **Database Encryption (SQLCipher).**

## Future Roadmap (SpendSense Pro)

- [ ] **Level 2 Deduplication: UTR/Ref ID Extraction.**
  Goal: Extract unique banking reference numbers for 100% foolproof duplicate prevention.
- [ ] **SpendSense Active Pay (UPI Integration).**
  Goal: Handle payments directly in-app for zero-ambiguity context.
- [ ] **Source Attribution (Multi-Bank).**
  Goal: Automatically track spending per bank account based on SMS headers.
- [ ] **Historical Reconciliation (Statement Import).**
  Goal: Bulk import PDF/CSV statements to backfill financial history.


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
Manifest Fixes** (Foundation).
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
