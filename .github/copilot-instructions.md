# GitHub Copilot Instructions for SpendSense

This document provides essential guidance for AI agents and Copilot sessions working on the SpendSense codebase.

## Build, Test, and Lint Commands

SpendSense is a Flutter project. All commands should be run from the `flutter_application_1/` directory.

### Setup
```bash
flutter pub get
```

### Running the App
```bash
# On a physical Android device (required for SMS and notifications)
flutter run
```

### Testing
```bash
# Run all tests
flutter test

# Run tests in a specific directory
flutter test test/services/

# Run a single test file
flutter test test/services/local_parser_test.dart

# Run with verbose output
flutter test --verbose

# Run tests with coverage (if coverage tooling is configured)
flutter test --coverage
```

### Linting and Analysis
```bash
# Analyze code for lint violations
dart analyze

# Run Flutter's static analysis (includes all lint rules defined in analysis_options.yaml)
flutter analyze

# Format code according to Dart style guide
dart format lib/ test/

# Check formatting without modifying files
dart format --set-exit-if-changed lib/ test/
```

### Building
```bash
# Build a debug APK
flutter build apk --debug

# Build a release APK
flutter build apk --release
```

**Exception:** One lint rule is intentionally disabled in `analysis_options.yaml`: `dangling_library_doc_comments` (library doc comments are not strictly required).

## High-Level Architecture

SpendSense is a **local-first, event-driven Android expense tracker** that captures payment SMS and routes them through a classification pipeline before storing them locally and optionally syncing to Google Sheets.

### Core Data Flow

1. **SMS Ingestion**: The `SmsService` (using the custom `telephony` plugin) captures incoming payment-like SMS in foreground and background
2. **Orchestration**: `AppState` (the central brain) receives the SMS event and manages the transaction lifecycle
3. **Classification Pipeline**:
   - **Local Regex** (`LocalParserService`): Extracts amount and merchant using hardcoded patterns for Indian banks
   - **Merchant Memory** (`merchant_memory` SQLite table): Checks if this merchant was categorized before
   - **Claude API** (optional): If enabled and unknown, sends to Anthropic for high-confidence categorization
4. **Persistence**: Every transaction is written to the `transactions` SQLite ledger immediately
5. **Review Flow**: Low-confidence transactions trigger:
   - Immediate popup notification, OR
   - Queued to a daily 9 PM digest screen
6. **Cloud Sync** (optional): Confirmed transactions sync to Google Sheets via `SheetsService` → Apps Script webhook

### Key Architectural Mandates

**CRITICAL** — These are not guidelines; they are design requirements:

1. **Local-First Integrity**: Every transaction MUST be persisted to SQLite (`LocalStorageService`) before ANY sync attempt. The local ledger is the source of truth.
2. **Centralized Orchestration**: All transaction lifecycle logic (received → classified → confirmed → synced) must be in `AppState.dart`. Do not scatter classification logic across UI or services.
3. **Merchant Memory Discipline**: The `merchant_memory` table is updated ONLY upon explicit user confirmation (manual popup or voice confirmation), not during automatic classification. This preserves data quality.
4. **Graceful Degradation**: If Claude API fails or returns low confidence, the transaction must NOT fail—it falls back to manual review mode (`is_confirmed = false`, `needs_user_input = true`).
5. **Immutability**: Use `copyWith()` on models (`MyTransaction`, `MerchantMemory`) instead of direct property mutation.

### Key Files and Responsibilities

| File | Responsibility |
|------|-----------------|
| `lib/state/app_state.dart` | Central orchestrator. Manages SMS → classification → persistence → sync pipeline. The highest-leverage file for business logic. |
| `lib/services/local_storage_service.dart` | SQLite interface. Manages `transactions` ledger, `merchant_memory` table, and schema migrations. Source of truth for all persisted data. |
| `lib/services/sms_service.dart` | SMS ingestion via the custom `telephony` plugin. Handles foreground/background SMS processing and permission management. |
| `lib/services/local_parser_service.dart` | Regex-based SMS parsing. Extracts amount, merchant, and optional category from bank/UPI SMS using hardcoded patterns. 100% unit tested. |
| `lib/services/claude_service.dart` | Encapsulates all calls to Anthropic's Claude API. Handles API errors gracefully and returns structured categorization results. |
| `lib/services/secure_storage_service.dart` | Encrypted key-value storage (Flutter Secure Storage). Stores Claude API key, Sheets webhook URL, and sensitive user configuration. |
| `lib/services/sheets_service.dart` | HTTP client for syncing transactions to Google Sheets via Apps Script webhook. Handles retry logic and network failures. |
| `lib/services/notification_service.dart` | Manages transaction popups and daily digest scheduling. Integrates with `flutter_local_notifications`. |
| `lib/models/transaction.dart` | Primary data model (`MyTransaction`). Defines transaction state, confidence levels, and category enums. |
| `backend/apps_script.js` | Server-side Apps Script code deployed to Google Sheets. Receives webhook payloads and updates the `Expenses` and `Loans` sheets. |

## Key Conventions

### Transaction Lifecycle States

Transactions flow through several states in the `AppState` enum (`TxState`):

- **PENDING**: Received SMS, waiting to be parsed
- **PARSED**: Local regex extracted merchant/amount, now checking merchant memory
- **MERCHANT_FOUND**: Merchant was in memory; using remembered category
- **WAITING_CLAUDE**: Sending to Claude API for classification
- **CLAUDE_RESPONSE**: Claude response received
- **CONFIRMED**: Transaction is classified with high confidence or user-confirmed
- **SYNCED**: Transaction successfully synced to Google Sheets (if enabled)
- **FAILED**: Unrecoverable error; transaction marked for manual review

### Database Schema

**Primary Tables:**

- `transactions`: The ledger. Stores `id`, `amount`, `merchant`, `category`, `timestamp`, `is_confirmed`, `needs_user_input`, `claude_confidence`, and sync metadata.
- `merchant_memory`: Stores `merchant_name`, `inferred_category`, `user_confirmed`, and `count` (frequency counter). Only updated when user confirms a categorization.

**Important Constraint**: Never directly modify `merchant_memory` during automatic classification. Only update it in response to explicit user actions.

### SMS Parsing and Deduplication

- `LocalParserService` uses regex patterns specific to Indian banks (HDFC, ICICI, Axis, UPI, etc.)
- Deduplication uses SHA-256 fingerprinting (`crypto` package) on a normalized SMS payload to prevent duplicate entries
- Fingerprinting is stored in the `transactions` table alongside the transaction record

### Error Handling and Logging

- Use `TxState` enum in `AppState` to track and communicate transaction status
- Avoid throwing exceptions in the SMS ingestion pipeline; always degrade gracefully
- Log important state transitions (e.g., "SMS received", "Claude API failed, falling back to manual review")

### Testing Philosophy

The project follows a **Testing Pyramid** (as defined in `Industry_Standard_App_Development_Guide.md`):

- **Unit Tests** (most): Service logic, parsers, models. Examples: `local_parser_test.dart`, `local_storage_test.dart`
- **Integration Tests** (medium): Multi-service workflows (e.g., end-to-end SMS → persist → sync)
- **Widget Tests** (few): UI components (low priority for alpha)

**Critical Coverage**: Tests for `LocalParserService` (100% of regex patterns) and `AppState` orchestration logic are non-negotiable before alpha launch.

### API Key and Secret Management

- **Never** commit API keys or webhook URLs in plain text to the codebase
- Store all secrets in `SecureStorageService` (Flutter Secure Storage on Android → Android Keystore)
- Configuration screen (`setup_screen.dart`) allows users to input their own keys at runtime
- For local development, use `.env` or environment variables; do not commit `.env` files

### Code Organization

- **Services** (`lib/services/`): Encapsulate external integrations (SMS, APIs, databases, storage)
- **Models** (`lib/models/`): Data structures (immutable, use `copyWith`)
- **State** (`lib/state/`): Orchestration logic (`AppState`)
- **UI** (`lib/ui/`): Flutter screens and widgets
- **Core** (`lib/core/`): Utilities, constants, enums

## Development Workflow (Mandatory for Agents)

### Traceability & Audit Trail

Every time you **implement a new feature**, **refactor critical logic**, or **debug a complex issue**:

1. **Analysis**: Create a detailed plan document:
   - Path: `flutter_application_1/feature_discussion/YYYY-MM-DD/[Feature_Name]_Plan.md`
   - Include: Problem statement, approach, affected files, risks

2. **Execution**: After implementing and testing, write an execution report:
   - Path: `flutter_application_1/feature_discussion/YYYY-MM-DD/[Feature_Name]_Execution.md`
   - Include: Changes made, test results, any deviations from plan

**Why?** This creates a durable audit trail organized by date. If a regression occurs, future developers can reference these logs to understand the context and implementation details of that day's changes.

### Documentation Maintenance

- **Repository Context**: Keep `SpendSense_Repository_Context.md` in sync with architecture changes (schema updates, new services, workflow changes)
- **Development Guide**: Update `Industry_Standard_App_Development_Guide.md` if adopting new standards (e.g., switching from `SharedPreferences` to `flutter_secure_storage`)

## Known Gaps & Alpha-Stage Limitations

- **Deduplication**: Currently uses SHA-256 fingerprinting; lacks a deterministic strategy for edge cases (rapid identical purchases)
- **Idempotency**: Google Sheets sync is append-only; retries can result in duplicate rows
- **Domain Scope**: Optimized for `EXPENSE` and `LOAN` types; `INCOME` and `REFUND` are not yet first-class
- **E2E Testing**: Minimal automated E2E test coverage; priority for alpha is unit tests of `LocalParserService` and `AppState`

## Getting Started on a New Task

1. **Read** `GEMINI.md` and `Get_Started.md` for high-level context
2. **Consult** `SpendSense_Repository_Context.md` for detailed architecture and file responsibilities
3. **Check** `SpendSense_Codebase_TODO.md` for current priorities
4. **Follow** the Traceability Workflow: create a plan document before making changes
5. **Run tests** before and after changes to ensure nothing breaks
