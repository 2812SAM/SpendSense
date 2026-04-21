# Action Plan: Deduplication Refinement & Simulator Fix

## Overview
This plan addresses the "False Positive" risks in our current deduplication logic and fixes the "Simulation Block" issue in Developer Tools. We will move to a high-resolution hashing strategy.

---

## 1. Objectives
- **Zero False Positives:** Ensure two legitimate transactions for the same amount at the same time are NOT deduplicated.
- **Robust Network Protection:** Block 100% of duplicate SMS deliveries from the network.
- **Improved DX:** Ensure the simulator can be used repeatedly without manual database wipes.

---

## 2. Implementation Strategy

### **A. Secure Fingerprinting**
- Replace the `Sender_Amount_Time` string with a **SHA-256 Hash** of the entire SMS body.
- This ensures that if even one character changes (like a Ref No or Timestamp in the SMS), the code is different.

### **B. Simulator Unblocking**
- Update `DeveloperToolsScreen` to append a hidden unique identifier (Salt) to simulated messages.
- Example: `[Real SMS Body] | dev_salt: [Random ID]`
- This makes every simulation unique while still testing the Parser's ability to read the main text.

---

## 3. Technical Tasks
- [ ] **Dependency:** Add `crypto: ^3.0.3` to `pubspec.yaml`.
- [ ] **Refactor `AppState._generateFingerprint`**:
    - Take the raw SMS string as input.
    - Return a SHA-256 hex string.
- [ ] **Update `DeveloperToolsScreen`**:
    - Modify simulation buttons to append a unique timestamp/salt to the SMS body.

---

## 4. Verification Plan
- [ ] **Verification:** Send an HDFC simulation twice. It should be blocked.
- [ ] **Verification:** Wait 1 second and send again. It should be LOGGED (because the salt changed).
- [ ] **Verification:** Verify that real parsing still works even with the salt at the end.

---

## 5. Security & Traceability
- Logic will be documented in `Deduplication_Refinement_Execution.md`.
- No user-facing changes (Purely architectural).
