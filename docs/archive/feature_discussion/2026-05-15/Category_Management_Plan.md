# Category Management Implementation Plan

## 1. Specifications
*   **Database:** 
    *   Update `custom_categories` table to include `emoji` column.
    *   Initialize `custom_categories` with default system categories on first run or via a sync mechanism.
*   **UI:** 
    *   `CategoryManagementScreen`: List view of all categories.
    *   `EditCategoryDialog`: Modal for name and emoji input.
*   **Logic:** 
    *   Cascading updates for renames.
    *   Reassignment logic for deletions.
    *   Centralized `CategoryService` in `AppState`.

## 2. In Scope
*   CRUD operations for categories with emoji support.
*   Database migrations.
*   UI implementation (Screen + Dialogs).
*   Cascading updates to `transactions` and `merchant_memory`.
*   Unit tests for database and state logic.

## 3. Out of Scope
*   Syncing category *definitions* to Google Sheets.
*   Complex emoji picker widgets (native keyboard used instead).

## 4. Final Goal
*   Empower users to personalize their spending categories with dynamic emojis and managed labels.

## 5. Acceptance Criteria
1.  **Navigation:** Accessible via Settings.
2.  **Creation:** Can add new category + emoji.
3.  **Editing:** Can rename/change emoji of custom categories.
4.  **Cascading:** Renames update historical transactions and merchant memories.
5.  **Deletion Safety:** Cannot delete category with active transactions without reassignment.
6.  **Dynamic UI:** All screens use the new dynamic category-emoji mapping.

## 6. Edge Cases & Probable Bugs (Iteration 2/3)
*   **Case 1: Reserved Names.** User tries to rename a category to a name that already exists (e.g., "Food" to "Shopping").
    *   *Fix:* Validation logic to prevent duplicates.
*   **Case 2: System Integrity.** Deleting a category that is currently assigned to a `merchant_memory` key.
    *   *Fix:* Deletion logic must check both `transactions` and `merchant_memory`.
*   **Case 3: Migration.** Existing custom categories have no emojis.
    *   *Fix:* Default to '🏷️' for existing custom categories during migration.
*   **Case 4: Race Conditions.** SMS arrives while category is being renamed.
    *   *Fix:* Use SQLite transactions for the cascading update.

## 7. Implementation Roadmap
1.  **Test Phase:** Write unit tests for `LocalStorageService.renameCategory` and `deleteCategory`.
2.  **Logic Phase:** Update `LocalStorageService` and `AppState`.
3.  **UI Phase:** Create management screens and dialogs.
4.  **Verification Phase:** Run tests and manual UI walk-through.
