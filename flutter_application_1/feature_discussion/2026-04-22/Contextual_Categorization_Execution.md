# Execution Report: Contextual Categorization (Static vs. Dynamic)

## Summary of Changes
Implemented an intelligent categorization engine that differentiates between businesses (Static) and personal contacts (Dynamic), ensuring accurate tracking for multi-purpose payments.

### 1. Storage & Data Integrity
- **Database Migration (v4):** Incremented `dbVersion` to `4` and implemented an `onUpgrade` script to add the `is_dynamic` boolean column to the `merchant_memory` table.
- **Model Refined:** Updated `MerchantMemory` model to support the new flag, ensuring standard serialization and immutability (via `copyWith`).

### 2. Intelligent Routing (`AppState`)
- **Memory Logic:** Refactored `_onPaymentSmsReceived` to evaluate the `is_dynamic` flag:
    - **Fixed Merchants:** If `is_dynamic` is false, the app auto-logs the transaction silently (e.g., Daily Juice Shop).
    - **Dynamic Peers:** If `is_dynamic` is true, the app pre-fills the category as a suggestion but **always** triggers a Manual Review popup (e.g., payments to Girdhar).
- **Confirmation Flow:** Updated `confirmCategory` and `confirmAll` to save the user's preference for "Remembering" a merchant.

### 3. User Experience Refinement
- **Popup & Digest Screens:**
    - Converted the "1-tap" flow into a "Select and Confirm" flow.
    - Added a **`[x] Remember this category...`** checkbox.
    - Unchecking this box saves the contact as "Dynamic", ensuring the app asks for context next time.
- **Deduplication:** Maintained high-resolution SHA-256 fingerprinting to prevent accidental double-logging during the manual review process.

## Verification Results
- [x] **Backwards Compatibility:** Confirmed that existing merchant memories migrate to v4 with `is_dynamic: false` by default.
- [x] **Dynamic Flow:** Verified that if "Remember" is unchecked, the next payment to the same name triggers a new review prompt instead of auto-logging.
- [x] **Static Flow:** Verified that if "Remember" is checked, future payments are logged instantly without user intervention.

## Conclusion
SpendSense now understands the difference between a shop and a friend. This prevents "category pollution" where personal transfers might accidentally be lumped into a single category, while maintaining "Zero-Touch" automation for regular businesses.
