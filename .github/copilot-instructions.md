# GitHub Copilot Instructions for SpendSense

This document provides the canonical guidance for AI agents and Copilot sessions working on the SpendSense codebase.

## Build, Test, and Lint Commands

SpendSense is a Flutter project nested inside this repository. Run Flutter and Dart commands from the `flutter_application_1/` directory.

### Setup
```bash
flutter pub get
```

### Running the App
```bash
# A physical Android device is required for SMS and notification flows.
flutter run
```

### Testing
```bash
flutter test
flutter test test/services/
flutter test test/services/local_parser_test.dart
flutter test --coverage
```

### Linting and Analysis
```bash
dart analyze
flutter analyze
dart format lib/ test/
dart format --set-exit-if-changed lib/ test/
```

### Building
```bash
flutter build apk --debug
flutter build apk --release
```

## High-Level Architecture

SpendSense is a local-first, event-driven Android expense tracker that captures payment SMS, routes them through a classification pipeline, stores every transaction locally, and optionally syncs confirmed entries to Google Sheets.

### Core Data Flow

1. `SmsService` captures payment-like SMS in foreground and background.
2. `AppState` orchestrates classification and transaction lifecycle decisions.
3. `LocalParserService` attempts local extraction first.
4. `LocalStorageService` checks merchant memory and persists every transaction to SQLite.
5. Optional Claude categorization is used only when local intelligence is insufficient and a key is present.
6. Low-confidence items are routed to popup and digest review flows.
7. Confirmed items optionally sync through `SheetsService` to the Apps Script webhook.

### Architectural Mandates

1. Local-first integrity: every transaction must be persisted to SQLite before any sync attempt.
2. Centralized orchestration: transaction lifecycle logic belongs in `lib/state/app_state.dart`.
3. Merchant memory discipline: update `merchant_memory` only from explicit user confirmation flows.
4. Graceful degradation: if Claude fails or is unavailable, fall back to manual review instead of dropping data.
5. Immutability: update models through `copyWith()` instead of mutating fields directly.

### Key Files

| File | Responsibility |
|------|----------------|
| `flutter_application_1/lib/state/app_state.dart` | Core SMS -> classify -> persist -> sync orchestration |
| `flutter_application_1/lib/services/local_storage_service.dart` | SQLite ledger, merchant memory, migrations |
| `flutter_application_1/lib/services/sms_service.dart` | SMS ingestion and queue handling |
| `flutter_application_1/lib/services/local_parser_service.dart` | Local regex-based parsing |
| `flutter_application_1/lib/services/claude_service.dart` | Optional AI categorization and voice interpretation |
| `flutter_application_1/lib/services/secure_storage_service.dart` | Secret storage |
| `flutter_application_1/lib/services/sheets_service.dart` | Google Sheets sync client |
| `flutter_application_1/lib/services/notification_service.dart` | Popup and digest notification handling |
| `flutter_application_1/backend/apps_script.js` | Apps Script webhook backend |
| `docs/architecture/repository-context.md` | Durable architecture reference |
| `docs/development/codebase-todo.md` | Current backlog and priorities |

## Documentation Workflow

1. Use `.ai/` for temporary planning notes, scratch analysis, and disposable AI working files. Do not commit day-to-day plan or execution logs.
2. Keep durable documentation under `docs/`.
3. Update `docs/architecture/repository-context.md` when architecture, schema, or workflow behavior changes.
4. Update `docs/development/codebase-todo.md` when priorities, open gaps, or follow-up tasks change.
5. Update `docs/development/industry-standard-guide.md` only when the team's engineering standards materially change.
6. Do not create new root-level Markdown files for routine work. Extend an existing document under `docs/` whenever possible.
7. `docs/archive/feature_discussion/` is historical reference material only. Do not resume the old dated plan/execution log pattern.

## Known Gaps & Alpha-Stage Limitations

- Deduplication uses SHA-256 fingerprinting today, but it does not yet use UTR or reference-ID-level matching.
- Google Sheets sync is append-only, so retries can still create duplicate cloud rows.
- The product is strongest for `EXPENSE` and `LOAN`; richer incoming/refund semantics still need work.
- Real-device SMS reliability still needs broader validation across devices and OEM variations.

## Getting Started on a New Task

1. Read this file first.
2. Read `flutter_application_1/README.md` for the quick project entry point.
3. Read `docs/architecture/repository-context.md` for detailed architecture and lifecycle context.
4. Check `docs/development/codebase-todo.md` for current priorities and known follow-ups.
5. Use `.ai/` for temporary planning if needed, and promote only durable conclusions into `docs/`.
6. Run tests before and after meaningful changes.
