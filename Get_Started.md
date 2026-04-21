# Welcome to SpendSense: AI Agent Onboarding & Workflow Guide

Welcome, AI Agent. You are assisting in the development of **SpendSense**, a local-first, privacy-focused expense tracker for Android. To ensure this project remains professional, stable, and maintainable, you MUST adhere to the following mandates.

---

## 1. Core Project Context
Before making any changes, you must read and internalize these two foundational documents:
1.  **`flutter_application_1/SpendSense_Repository_Context.md`**: This is the "Source of Truth" for the app's architecture, data flow, and file responsibilities.
2.  **`flutter_application_1/feature_discussion/Industry_Standard_App_Development_Guide.md`**: This defines the P0/P1/P2 standards for security, testing, and clean code that this project follows.

---

## 2. Mandatory "Traceability" Workflow
Every time you decide to **implement a new feature**, **refactor existing logic**, or **debug a complex error**, you must follow this two-step process:

### **Step 1: Analysis & Strategy**
Analyze the task and prepare a detailed action plan. Save this plan as a new Markdown file inside a folder named after the **current date** (format: `YYYY-MM-DD`) within the `flutter_application_1/feature_discussion/` directory.
- **Path Example:** `flutter_application_1/feature_discussion/2026-04-19/[Feature_Name]_Plan.md`

### **Step 2: Execution & Reporting**
After implementing the plan and verifying it through testing, write a detailed report of the changes you made in the same dated folder.
- **Naming Convention:** `[Feature_Name]_Execution.md` (e.g., `Biometric_Lock_Execution.md`)

**Why?** This creates a historical audit trail organized by date. If a future change causes a regression, we can refer to these logs to understand the context and implementation details of that specific day.

---

## 3. Documentation Maintenance
You are responsible for the health of this repository's documentation. 
- **Syncing:** Whenever you update core logic (e.g., changing the Database schema or the SMS ingestion flow), you MUST update the `SpendSense_Repository_Context.md` to reflect the new reality.
- **Standards:** If we adopt a new industry standard (e.g., moving from `SharedPreferences` to `flutter_secure_storage`), update the `Industry_Standard_App_Development_Guide.md`.

---

## 4. Engineering Mandates
- **Local-First:** SQLite is the primary source of truth. Cloud sync (Google Sheets) is an optional, background enhancement.
- **Zero-Hurdle:** The app must be functional instantly upon installation with zero technical setup.
- **Testing:** New logic is incomplete without accompanying Unit Tests. Aim for the "Testing Pyramid" defined in the guides.
- **Security:** Never store secrets in plain text. Always prioritize user privacy.

---

**Now, proceed by reading the Repository Context and identify the current highest priority task from the TODO list.**
