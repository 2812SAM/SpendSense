# Implementation Plan: Zero-Hurdle Onboarding & Local-First Intelligence

## Overview
This document outlines the transition of SpendSense from a "Cloud-Required" prototype to a "Zero-Hurdle" production-ready application. The goal is to allow users to start tracking expenses **instantly** without requiring any technical setup (API keys or webhooks).

---

## Phase 1: Foundation & UX Bypass (The "Instant Start")
*Goal: The user opens the app and reaches the Home Screen immediately.*

### Key Tasks:
1.  **Refactor `main.dart` Routing:**
    *   Change the initial route logic. Instead of checking if `onboarding_done` is true, check if **SMS Permissions** are granted.
    *   If permissions are missing, show a high-impact "Permission Request" screen explaining the value of automation.
    *   If granted, navigate straight to `HomeScreen`.
2.  **Manifest & Permission Hardening:**
    *   Move all permissions from `android_manifest_additions.xml` to the official `android/app/src/main/AndroidManifest.xml`.
    *   Implement a unified `PermissionService` to handle Android 13+ Notification and SMS permissions in a single, user-friendly flow.

---

## Phase 2: Local Intelligence (The "Parser")
*Goal: Replace mandatory AI calls with robust local logic.*

### Key Tasks:
1.  **Create `LocalParserService`:**
    *   Develop a library of **Regex Patterns** for major Indian banks (HDFC, SBI, ICICI, Axis, PNB).
    *   Extract `amount` and `merchant` locally from matching SMS.
2.  **Global Merchant Dictionary:**
    *   Implement a local keyword list for "Global Merchants" (e.g., "Zomato" -> Food, "Uber" -> Travel, "Jio" -> Bills).
    *   Categorize common expenses instantly with zero user input.
3.  **Prioritize Merchant Memory:**
    *   Modify `AppState` to check the SQLite `merchant_memory` table **before** attempting any AI classification.

---

## Phase 3: State Orchestration (The "Optional Brain")
*Goal: Update the app's orchestration to handle missing keys gracefully.*

### Key Tasks:
1.  **Refactor `AppState.dart` Workflow:**
    *   **Step 1:** Run `LocalParserService`.
    *   **Step 2:** Check `MerchantMemory`.
    *   **Step 3:** Check for `ClaudeApiKey`. If present, use it for ambiguity.
    *   **Step 4:** If no key and still unknown, save as `is_confirmed = false` and trigger a **Manual Review** notification.
2.  **Conditional Cloud Sync:**
    *   Only trigger `SheetsService` if a Webhook URL is configured. Otherwise, maintain the transaction as `local_only` with a "Not Synced" status.

---

## Phase 4: Reliability & Deduplication (The "Trust" Layer)
*Goal: Ensure the local ledger is accurate and free of noise.*

### Key Tasks:
1.  **SMS Fingerprinting:**
    *   Add a `fingerprint` column to the `transactions` table (Hash of SMS Body + Amount + Date).
    *   Reject duplicate entries before they enter the ledger or sync pipe.
2.  **UI Data Binding:**
    *   Fix the Home Screen to use `ChangeNotifier` or `StreamBuilder` for real-time updates when transactions are confirmed or synced.

---

## Phase 5: Advanced Connectivity (The "Power User" Setup)
*Goal: Make Cloud and AI setup a voluntary "upgrade."*

### Key Tasks:
1.  **Redesign `SetupScreen` into "Settings > Connections":**
    *   Change the blocking onboarding into optional toggles: `[ ] Enable AI Categorization` and `[ ] Enable Cloud Sync`.
2.  **Google Sign-In (Future):**
    *   Replace the manual "Apps Script" URL with a "Sign in with Google" button.
    *   Automate the creation of the "SpendSense" spreadsheet in the user's Drive.

---

## Success Metrics
- **Time to First Value (TTFV):** User sees their first tracked transaction within 2 minutes of installation.
- **Conversion Rate:** 90%+ of users complete onboarding (since it only requires 1 tap for permissions).
- **Local Accuracy:** 70%+ of common Indian bank SMS are correctly parsed without AI.
