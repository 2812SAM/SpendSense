---
name: zero-hurdle-onboarding
description: Execute the SpendSense zero-hurdle refactor history and validate the local-first onboarding flow. Use when the user wants to revisit or extend the original zero-hurdle implementation work.
---

# Zero-Hurdle Onboarding Refactor

This skill guides work related to SpendSense's shift from a cloud-required setup flow to a local-first onboarding experience.

## Workflow

### 1. Research & Baseline
- Read the historical plan at `docs/archive/feature_discussion/2026-04-19/Setup_Screen_Removal_Plan.md`.
- Verify the current state of `flutter_application_1/lib/main.dart` and `flutter_application_1/lib/state/app_state.dart`.
- Read `docs/architecture/repository-context.md` for the current architecture contract before editing behavior.

### 2. Foundation
- Confirm `SetupScreen` is optional and the app can start on the home flow without API keys.
- Confirm Android manifest permissions still match the live SMS, notification, and microphone requirements.

### 3. Local Intelligence
- Validate that local parsing and merchant memory run before optional AI classification.
- Use `references/bank_regex.md` for regex expectations.

### 4. Reliability
- Validate fingerprint-based deduplication in `AppState` and `LocalStorageService`.
- If behavior changes, keep the architecture and TODO docs in sync.

### 5. Settings UX
- Treat `flutter_application_1/lib/ui/screens/setup_screen.dart` as the advanced settings surface for optional AI and cloud configuration.

## Testing & Validation
- Follow `references/test_cases.md` for verification.
- Do not consider the task complete without checking the local ledger behavior empirically.
