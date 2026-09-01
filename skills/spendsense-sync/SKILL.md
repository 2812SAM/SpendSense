---
name: spendsense-sync
description: Syncs core project documentation with recent implementation history and audits the repo against the development guide. Use when the user wants docs refreshed after a task.
---

# SpendSense Sync & Audit Workflow

This skill keeps SpendSense documentation aligned with the implemented codebase and the retained historical archive.

## Workflow

### 1. Data Collection
- Read the current source of truth documents first:
  - `flutter_application_1/README.md`
  - `docs/architecture/repository-context.md`
  - `docs/development/codebase-todo.md`
- If historical context is relevant, inspect the archived implementation trail under `docs/archive/feature_discussion/`.
- Identify new features, behavior changes, bugs fixed, and follow-up risks.

### 2. Documentation Syncing
Update these files only when the task actually changed their subject matter:

- `flutter_application_1/README.md`
  - Refresh core features, setup, testing, or project-structure pointers.
- `docs/development/codebase-todo.md`
  - Mark implemented tasks complete.
  - Add new technical debt or follow-up work revealed by the change.
- `docs/architecture/repository-context.md`
  - Update lifecycle descriptions, source-of-truth tables, and file-responsibility notes.

### 3. Industry Standards Audit
- Read `docs/development/industry-standard-guide.md` as a read-only standard.
- Compare the current implementation against the standards.
- Add any meaningful gaps to `docs/development/codebase-todo.md`.

## Quality Mandate
- Make surgical updates instead of rewriting healthy sections without cause.
- Use archived `docs/archive/feature_discussion/` notes only as historical evidence, not as a second source of truth.
- Keep `docs/` authoritative for current documentation.
