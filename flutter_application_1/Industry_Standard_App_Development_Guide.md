# Industry-Standard App Development & Testing Guide

This document defines the professional benchmarks for mobile application development. Following these standards ensures that **SpendSense** is not just a prototype, but a scalable, secure, and reliable product.

---

## 1. Priority P0: Core Stability, Trust & Safety
*These must be implemented before any public "Alpha" or "Beta" release. Failure here results in data loss or security breaches.*

### **A. The Testing Pyramid (100% Non-Negotiable)**
- **Unit Tests (Logic):** Test `LocalParserService`, `AppState` logic, and `MyTransaction` models. 
    - *Industry Standard:* 80% code coverage.
- **Widget Tests (UI Components):** Ensure buttons, input fields, and banners behave correctly in isolation.
- **Integration Tests (End-to-End):** Automate the flow from "SMS Received" to "Logged in Sheets."

### **B. Security & Data Privacy**
- **Secure Storage:** Store the `Claude API Key` and `Webhook URL` in **Encrypted Storage** (e.g., `flutter_secure_storage`) rather than plain-text `SharedPreferences`.
- **Database Encryption:** Encrypt the SQLite database using **SQLCipher** to protect the user's financial history if their phone is lost.
- **Privacy Policy:** Implement a "Just-in-Time" permission explanation before asking for SMS or Microphone access.

### **C. Error Boundaries & Fallbacks**
- **Graceful Degradation:** If the internet is down, the app must continue to capture SMS and cache them locally without showing "Network Error" popups.
- **Global Error Handler:** Implement a `FlutterError.onError` and `PlatformDispatcher.instance.onError` to catch and log crashes instead of showing the "Red Screen of Death."

---

## 2. Priority P1: Scalability, Maintenance & DevOps
*These ensure that the app can be maintained by a team and survives OS updates.*

### **A. Architecture: Clean Architecture / BLoC**
- **Decoupling:** Separate the "UI" (Widgets) from the "Business Logic" (Blocs/Services) and the "Data Source" (SQLite/APIs).
- **Dependency Injection (DI):** Stop using `Service.instance` (Singletons). Use `Provider` or `GetIt` to inject services. This makes testing and swapping services (e.g., switching from Claude to Gemini) trivial.

### **B. Code Linting & Static Analysis**
- **Strict Linting:** Use `flutter_lints` with additional rules (e.g., `prefer_const_constructors`, `avoid_print`).
- **Static Analysis:** Fail the build if there are any "Warnings" in the code.

### **C. Git Flow & CI/CD**
- **Branching Strategy:** Never commit directly to `main`. Use `feature/` branches and **Pull Requests (PRs)**.
- **CI/CD Pipeline:** Use GitHub Actions to automatically run tests and lint checks every time you push code.
- **Semantic Versioning:** Follow `v1.2.3` (Major.Minor.Patch) logic for all releases.

### **D. Observability & Telemetry**
- **Crash Reporting:** Integrate **Sentry** or **Firebase Crashlytics**.
- **User Analytics:** Track *events* (e.g., "User confirmed transaction via voice"), not *users* (to preserve privacy).

---

## 3. Priority P2: User Delight & Global Reach
*These transform a "good" app into a "great" app.*

### **A. Accessibility (A11y)**
- **Screen Readers:** Ensure all icons have `semanticLabel` for visually impaired users.
- **Contrast:** Maintain a high contrast ratio for text readability.

### **B. Localization (i18n)**
- **Multi-language Support:** Use `.arb` files to support languages like Hindi, Marathi, or Tamil, alongside English.

### **C. Performance Budget**
- **Jank Free:** Maintain 60 FPS (or 120 FPS) animations.
- **Startup Time:** The app should be interactable within 2 seconds of the splash screen appearing.
- **Battery Optimization:** Minimize background polling. Only wake the CPU when a valid payment SMS is actually received.

---

## 4. SpendSense Gap Analysis & Comparison

| Parameter | Industry Standard (Professional) | SpendSense Current State (Alpha) | Priority to Fix |
| :--- | :--- | :--- | :--- |
| **Logic Verification** | 100% Unit Tested | 100% Core Logic Tested | ✅ **DONE** |
| **Secret Storage** | Encrypted Vault | SecureStorage (Encrypted) | ✅ **DONE** |
| **Background Tasks** | Native WorkManager | Simple Foreground/Background Listener | **P1** |
| **UI State** | Reactive (Streams/BLoC) | Imperative (ChangeNotifier) | **P1** |
| **Deployment** | Automated CI/CD | Manual "Flutter Run" | **P1** |
| **Architecture** | Dependency Injection | Initial DI Refactor Done | ✅ **IN PROGRESS** |

---

## 5. Summary Recommendation for Upcoming Development

1.  **Immediate (P0):** Write **Unit Tests** for `LocalParserService`. It is the core of the app.
2.  **Immediate (P0):** Move API keys to **Secure Storage**.
3.  **Near-Term (P1):** Implement **Sentry** for error tracking.
4.  **Near-Term (P1):** Refactor `AppState` to use **Dependency Injection** so you can test it without real hardware.
