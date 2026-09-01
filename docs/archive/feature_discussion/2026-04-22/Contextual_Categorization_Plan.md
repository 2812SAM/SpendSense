# Action Plan: Contextual Categorization (Static vs. Dynamic Merchants)

## Overview
This plan implements the "Contextual Categorization" feature. It differentiates between static merchants (1:1 relation, like a juice shop) where the category is auto-logged, and dynamic peers (1:N relation, like a friend) where the app will always ask for the context of the payment.

---

## 1. Storage & Model Updates (SQLite)
**Goal:** Add a flag to the merchant memory to distinguish between fixed and dynamic categorizations.

- **Action:** Update `lib/models/merchant_memory.dart`.
    - Add `final bool isDynamic;` to the class, constructor, `fromMap`, `toMap`, and `copyWith`.
- **Action:** Update `lib/core/constants.dart`.
    - Increment `dbVersion` to `4`.
- **Action:** Update `lib/services/local_storage_service.dart`.
    - Update `_createMerchantMemoryTable` to include `is_dynamic INTEGER NOT NULL DEFAULT 0`.
    - Update `_onUpgrade` to handle `oldVersion < 4` by running `ALTER TABLE merchant_memory ADD COLUMN is_dynamic INTEGER NOT NULL DEFAULT 0`.
    - Update `saveMerchantMemory` to accept and save the `isDynamic` boolean.

---

## 2. UI/UX Refactor (Popup & Digest)
**Goal:** Allow the user to decide if a categorization is a "fixed rule" or a "one-time context" when reviewing.

- **Interaction Shift:** We need to move away from the "instant 1-tap categorization" to a "select and confirm" flow to allow the user to toggle the memory setting.
- **Action:** Update `lib/ui/screens/popup_screen.dart` & `lib/ui/screens/digest_screen.dart`.
    - Add a state variable to track the `selectedCategory`.
    - Add a Checkbox/Toggle below the categories: `[x] Remember this category for future payments to [Merchant]`. (Default to true for convenience).
    - Add a "Confirm" button that triggers the save action, passing both the `category` and the `!remember` (which translates to `isDynamic`) state.

---

## 3. Orchestration Logic (`AppState`)
**Goal:** Use the new `isDynamic` flag to route incoming SMS correctly.

- **Action:** Update `lib/state/app_state.dart`.
    - Modify `confirmCategory` to accept `bool isDynamic`. Pass this to `saveMerchantMemory`.
    - Modify `_onPaymentSmsReceived`:
        - When `lookupMerchant` finds a match:
            - If `memory.isDynamic == false` (Fixed): Auto-categorize and log silently (current behavior).
            - If `memory.isDynamic == true` (Dynamic peer): Do **NOT** auto-log. Instead, set `needsUserInput: true` and trigger the Manual Review popup. 
            - *UX Polish:* We can pre-fill the transaction's category with the last used category from memory as a "suggestion", but keep `isConfirmed = false` so the user still has to review it.

---

## 4. Verification Plan
- **Migration:** Verify existing v3 database upgrades to v4 without losing merchant memory.
- **Fixed Flow:** Categorize a new merchant with "Remember" checked -> Send identical SMS -> Verify it auto-logs silently.
- **Dynamic Flow:** Categorize a new merchant with "Remember" UNCHECKED -> Send identical SMS -> Verify the popup appears again, asking for context.
