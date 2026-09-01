# Action Plan: Internal Developer Tools (DX)

## Overview
This plan describes the implementation of a hidden **Developer Tools** menu in SpendSense. This is not a user-facing feature but an internal utility to facilitate rapid testing, SMS simulation, and state debugging without real transactions.

---

## 1. Objectives
- **Simulate Real Scenarios:** Trigger HDFC, SBI, ICICI, and Axis SMS parsing flows instantly.
- **State Management Debugging:** Simulate sync failures and notification triggers.
- **Database Utilities:** Quick reset of the local ledger and merchant memory.
- **Security:** Ensure these tools are strictly stripped from production builds using `kDebugMode`.

---

## 2. Implementation Strategy

### **A. UI Entry Point**
- Add a "Developer Options" tile at the bottom of the `SetupScreen` (Settings).
- This tile will only be rendered if `foundation.kDebugMode` is true.
- Clicking the tile opens a new `DeveloperToolsScreen`.

### **B. Simulation Logic**
- **SMS Simulation:** Use `AppState.onPaymentSmsReceived` (already exposed for testing) to inject hardcoded bank SMS samples.
- **Database Reset:** Call `LocalStorageService` to truncate tables.
- **Sync Mocking:** (Optional) Add a toggle in `AppState` to force `SheetsService.logMyTransaction` to return `false` to test retry logic.

### **C. Screen Components**
- **Section: SMS Injection**
    - Button: "Simulate HDFC (Rs. 100)"
    - Button: "Simulate SBI (Rs. 500)"
    - Button: "Simulate Unknown/Manual Review"
- **Section: Database Management**
    - Button: "Clear All Transactions" (Dangerous - Red Color)
    - Button: "Clear Merchant Memory"
- **Section: Configuration**
    - Toggle: "Force Sync Failures"

---

## 3. Technical Tasks
- [ ] **Define Samples:** Add a constant file `lib/core/debug_samples.dart` containing bank SMS templates.
- [ ] **Refactor `SheetsService`:** Add a `debugForceFail` flag to simulate network issues.
- [ ] **Create `DeveloperToolsScreen`:** A simple list-view based utility screen.
- [ ] **Update `SetupScreen`:** Add the conditional entry point.

---

## 4. Verification Plan
- [ ] **Build Check:** Verify the menu is visible in `flutter run` (Debug mode).
- [ ] **Production Check:** Build an APK (`flutter build apk`) and verify the menu is completely absent.
- [ ] **Functionality:** 
    - Click "Simulate HDFC" -> Transaction appears on Home instantly.
    - Click "Clear All" -> Home screen becomes empty.
    - Toggle "Force Sync Fail" -> New transactions show "Failed" status in SQLite.

---

## 5. Security Mandate
All debug code MUST be wrapped in:
```dart
if (kDebugMode) {
  // Debug logic only
}
```
Never store hardcoded API keys in the debug menu.
