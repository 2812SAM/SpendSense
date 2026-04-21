---
name: zero-hurdle-onboarding
description: Execute the SpendSense 'Zero-Hurdle' refactor to remove mandatory setup screens, implement local SMS parsing, and enable local-first expense tracking. Use this skill when the user wants to implement the "Zero-Hurdle Implementation Plan" from the feature_discussion folder.
---

# Zero-Hurdle Onboarding Refactor

This skill guides the implementation of the "Zero-Hurdle" plan, which moves SpendSense from a Cloud-Required to a Local-First model.

## Workflow

### 1. Research & Baseline
- Read `flutter_application_1/feature_discussion/Zero_Hurdle_Implementation_Plan.md`.
- Verify the current state of `lib/main.dart` and `lib/state/app_state.dart`.

### 2. Phase 1: Foundation (UX Bypass)
- **Action:** Update `lib/main.dart` to make `SetupScreen` optional.
- **Action:** Fix `AndroidManifest.xml` to include all required permissions (SMS, Mic, Notifs).
- **Validation:** Clear `SharedPreferences` and verify the app lands on `HomeScreen`.

### 3. Phase 2: Local Intelligence (Parsing)
- **Action:** Create `lib/services/local_parser_service.dart`.
- **Reference:** Use `references/bank_regex.md` for regex patterns and keyword dictionaries.
- **Action:** Integrate this service into `AppState.dart` to process incoming SMS locally.

### 4. Phase 3: State Orchestration (Optional Brain)
- **Action:** Refactor `AppState.dart` to prioritize `LocalParserService` and `MerchantMemory`.
- **Action:** Only call `ClaudeService` if a key is present.
- **Action:** Mark transactions as "Manual Review" if no key is present and classification is ambiguous.

### 5. Phase 4: Reliability (Deduplication)
- **Action:** Update `LocalStorageService.dart` to implement fingerprinting (Hashing SMS body + amount + date).
- **Validation:** Send identical SMS payloads and verify only one database entry is created.

### 6. Phase 5: UI Redesign (Settings)
- **Action:** Redesign `lib/ui/screens/setup_screen.dart` to act as an "Advanced Settings / Connections" page.
- **Action:** Add toggles for "Enable AI" and "Enable Cloud Sync".

## Testing & Validation
Follow the step-by-step validation guide in `references/test_cases.md` for every phase. Never consider a phase complete without empirical verification of the local ledger state.
