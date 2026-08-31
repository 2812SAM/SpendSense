# Action Plan: Deduplication Window, Notification Fix & UI Aggregation

## Overview
This plan addresses the deduplication time window, the "Merchant Memory" lookup logic for unknown senders, the bug where notifications aren't cleared, and the UI enhancement to group transactions by category on the Home screen.

---

## 1. Deduplication Time Window & Memory Fallback
**Goal:** Allow legitimate identical transactions after a short timeframe and fix "Remember" for unknown senders.

- **Action:** Update `lib/state/app_state.dart`.
    - Modify `_generateFingerprint` to include a 60-second window in the SHA-256 hash (`timestampInSeconds ~/ 60`).
    - Modify `_onPaymentSmsReceived` to use `_fallbackMerchantName` if `_extractMerchantHint` returns empty, ensuring "Remember" works for `UNKNOWN` senders.

---

## 2. Notification Clearing Bug
**Goal:** Ensure the notification disappears after a transaction is categorized.

- **Action:** Update `lib/services/notification_service.dart` and `lib/ui/screens/popup_screen.dart`.
    - The `flutter_local_notifications` plugin needs to be explicitly told to cancel the notification by its ID when the user confirms the category in the popup.
    - We will map the transaction ID (or a hashed integer of it) to the notification ID so it can be dismissed upon confirmation.

---

## 3. UI Aggregation (Home Screen)
**Goal:** Group transactions of the same category (or merchant) together on the Home screen to avoid clutter (e.g., 3 Food transactions become 1 "Food" row with the total amount).

- **Action:** Update `lib/ui/screens/home_screen.dart` and `lib/services/recent_transactions_service.dart`.
    - Modify the "Recent Transactions" list. Instead of rendering a 1:1 list of every single SMS, we will aggregate the data.
    - If the user wants a categorized view, we will group the `fetchRecent()` results by `category` (or `merchant`), summing the `amount` for each group before displaying them in the list.

---

## 4. Developer Tools Simulator
- **Action:** Update `lib/ui/screens/developer_tools_screen.dart`.
    - Add `Simulate EXACT Unknown (No Salt)` button to easily test the 60-second deduplication window and the fixed memory fallback.

---

## 5. Verification Plan
- **Verification 1:** Click `Simulate EXACT Unknown`. Categorize and check "Remember". Ensure the notification disappears.
- **Verification 2:** Wait 61 seconds. Click the button again. It should auto-log.
- **Verification 3:** Send 3 "Food" SMS simulations. The Home screen should show a single "Food" entry with the combined total amount.
