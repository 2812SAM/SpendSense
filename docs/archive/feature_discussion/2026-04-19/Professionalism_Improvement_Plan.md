# Action Plan: Professionalism Improvement (P0 Tasks)

This plan addresses the highest priority (P0) gaps identified in the `Industry_Standard_App_Development_Guide.md`.

## 1. Unit Testing the `LocalParserService`
**Goal:** Achieve 100% logic verification for SMS parsing across multiple bank formats.

### **Tasks:**
- [ ] **Create Test Suite:** Create `test/services/local_parser_test.dart`.
- [ ] **Bank Coverage:** Write 5+ test cases for each bank:
    - [ ] HDFC (Standard, edge case with decimals, edge case with large amounts).
    - [ ] ICICI (Standard and variation in merchant strings).
    - [ ] SBI (Standard and UPI variations).
    - [ ] Axis (Standard and P2M variants).
- [ ] **Keyword Coverage:** Verify that global keywords (Zomato, Uber, etc.) correctly trigger categories.
- [ ] **Failure Handling:** Verify that malformed SMS returns `null` instead of crashing.

---

## 2. Implementing Secure Storage for Secrets
**Goal:** Protect the Claude API Key and Webhook URL from plain-text exposure.

### **Tasks:**
- [ ] **Create `SecureStorageService`:** Encapsulate `flutter_secure_storage` logic to avoid direct dependency on the library throughout the app.
- [ ] **Migration Logic:**
    - On app launch, check if keys exist in `SharedPreferences`.
    - If found, copy them to `SecureStorage`.
    - Delete them from `SharedPreferences` to ensure security.
- [ ] **Update `AppState`:** Refactor `AppState` to read API keys from `SecureStorageService`.
- [ ] **Update `SetupScreen`:** Refactor the save logic to write to `SecureStorage`.

---

## 3. Automated Linting & Static Analysis
**Goal:** Enforce clean code standards automatically.

### **Tasks:**
- [ ] **Enable Strict Rules:** Update `analysis_options.yaml` with industry-standard strict rules (e.g., `always_declare_return_types`, `avoid_unnecessary_containers`).
- [ ] **Static Check:** Run `flutter analyze` to verify the codebase against the new rules.

---

## Success Metrics:
- `flutter test` passes with 100% success rate for the `LocalParserService`.
- `flutter analyze` returns zero warnings.
- Claude API key is confirmed to be missing from `SharedPreferences` after the first migration run.
