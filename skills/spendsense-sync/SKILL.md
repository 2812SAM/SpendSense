---
name: spendsense-sync
description: Syncs core project documentation (README, TODO, Context) with recent implementation reports from feature_discussion and audits gaps against industry standards. Use when the user says "Sync" or wants to update docs after a task.
---

# SpendSense Sync & Audit Workflow

This skill ensures that the repository's documentation is always aligned with the latest code changes and industry standards.

## Workflow

### 1. Data Collection
- Identify the folder for **today's date** in `flutter_application_1/feature_discussion/YYYY-MM-DD/`.
- Read all `*_Execution.md` files within that folder.
- Identify:
    - New features implemented.
    - Logic refactored.
    - Bugs fixed.
    - Changes to setup or dependencies.

### 2. Documentation Syncing
Update the following files **only if** the execution reports contain relevant changes:

- **README.md**:
    - Update "Core Features" if new functionality was added.
    - Update "Getting Started" if setup steps changed.
    - Update "Important Files" if new services/models were created.

- **SpendSense_Codebase_TODO.md**:
    - Mark implemented tasks as `[x]`.
    - Add new technical debts or future improvements identified during implementation.
    - Adjust priority levels based on current project maturity.

- **SpendSense_Repository_Context.md**:
    - Update the **Architecture Diagram** (Mermaid) if data flow changed.
    - Update **Source of Truth** tables if storage logic shifted.
    - Update **Component Breakdown** if new services or screens were added.

### 3. Industry Standards Audit
- Read `flutter_application_1/feature_discussion/Industry_Standard_App_Development_Guide.md` as a **read-only reference**.
- Analyze the current state of the repo against the P0, P1, and P2 standards defined in the guide.
- **Identify Gaps**:
    - Are new secrets being stored in plain text?
    - Did new logic get added without unit tests?
    - Is state management becoming too coupled?
- **Action**: Add these gaps as new P0/P1 tasks in `SpendSense_Codebase_TODO.md`. **Do not update the Industry Standard guide itself.**

## Quality Mandate
- **Surgical Updates**: Do not overwrite entire files. Use precise `replace` calls to preserve existing history.
- **Traceability**: Mention the specific execution report (e.g., `Setup_Screen_Removal_Execution.md`) in the edit instruction.
