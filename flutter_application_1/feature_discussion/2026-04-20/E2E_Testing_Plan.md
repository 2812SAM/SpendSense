# Action Plan: End-to-End Testing (Post-Refactor)

This plan outlines the systematic verification of SpendSense after the "Zero-Hurdle" and "Professionalism" refactors.

## 1. Test Environment Setup
- **Device:** Real Android device (Preferred) or Emulator with SMS redirection.
- **Tools:** `adb` for simulating SMS, Flutter DevTools for database inspection.
- **Baseline:** Clear all app data/cache to simulate a first-time user.

## 2. Test Suite: Core Workflows

### **A. The "Zero-Hurdle" Entry**
- [ ] **First Run:** Install and open. Verify the app lands on `HomeScreen` instantly.
- [ ] **Permissions:** Grant SMS and Notification permissions. Verify the "Status Pill" updates to "Ready".

### **B. Local Parsing Pipeline**
Using `adb` or a real payment, trigger the following SMS formats:
- [ ] **HDFC Test:** `Alert: You've spent Rs. 100.00 at Starbucks on 2026-04-20.`
- [ ] **SBI Test:** `Transaction of Rs. 250.00 on SBI UPI... to Swiggy.`
- [ ] **Expected Result:** Transactions appear in the Home feed with correct Merchant and Category within 1 second.

### **C. Reliability & Deduplication**
- [ ] **Double-Log Test:** Send the EXACT same HDFC SMS twice.
- [ ] **Expected Result:** Only one entry appears in the Home feed. Check logs for "SpendSense: SMS deduplicated".

### **D. Secret Migration & Encryption**
- [ ] **Legacy Migration:** (If possible) Install an old build with a plain-text key, then upgrade to the new build.
- [ ] **Expected Result:** Key should be automatically moved to `SecureStorage` and deleted from `SharedPreferences`.
- [ ] **Verification:** Use the new "Settings" UI to confirm the Claude key is still "Connected".

### **E. Manual Review Flow**
- [ ] **Unknown SMS:** Send a non-bank SMS that still contains "spent" or "debited".
- [ ] **Expected Result:** Notification appears -> Tap notification -> Popup opens -> Manually categorize as "Food" -> Verify entry on Home.

---

## 3. Bug Hunting & Edge Cases
- [ ] **Airplane Mode:** Receive SMS (queued by system), then open app. Verify parsing happens when app wakes.
- [ ] **Empty Fields:** Try saving Settings with only a Webhook but no Claude Key. Verify sync works while AI is bypassed.

## 4. Reporting
All failures will be logged in `E2E_Testing_Execution.md` with stack traces for immediate fixing.
