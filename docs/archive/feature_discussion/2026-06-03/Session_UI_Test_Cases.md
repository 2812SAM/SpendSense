# Session UI Test Cases: Goal-Driven Engine & Unified Review

This document outlines the step-by-step manual testing procedures to verify the features implemented in this session.

---

## Test Suite 1: The "Ignore" Data Cleanse

**Goal:** Verify that ignored transactions are completely hidden from all financial metrics.

1.  **Preparation:** Open the app and note your "Total Spent" on the Home Screen.
2.  **Action:** Spawn a fake transaction using Developer Options -> `Simulate Unknown (Manual Review)`.
3.  **Execute:** Tap the notification or open the Review tab to view the `PopupScreen` or `DigestScreen`.
4.  **Click:** Tap the **"Ignore this transaction"** button at the bottom of the screen.
5.  **Verification:**
    *   Return to the Home Screen. Your "Total Spent" should **not** have increased.
    *   Go to the Insights tab. The ignored transaction should **not** appear in any recent transaction lists or trend charts.

---

## Test Suite 2: Unified Manual Review & Deselection

**Goal:** Verify the UI/UX consistency, deselection logic, and safe learning defaults.

1.  **Preparation:** Spawn an unknown transaction and open the Review tab (`DigestScreen`).
2.  **Action 1 (Selection):** Tap the `Food` category chip.
    *   **Verification:** The chip highlights. The "Auto-categorize in future" toggle appears and is **unchecked** by default.
3.  **Action 2 (Deselection):** Tap the `Food` category chip again.
    *   **Verification:** The chip un-highlights. The "Auto-categorize" toggle disappears. The Progress Bar does *not* increase.
4.  **Action 3 (Progress):** Select `Food` again, then tap the **"Next"** button.
    *   **Verification:** The Progress Bar % now increases.
5.  **Action 4 (Save & Exit):** Spawn 3 unknown transactions. Categorize only the first one, then tap the **"Done"** button in the top right of the AppBar.
    *   **Verification:** The screen closes. The 1 categorized transaction is saved, and the remaining 2 stay in the pending queue.

---

## Test Suite 3: Expense Classification (Recurring vs. Flexible)

**Goal:** Verify manual overrides for expense types in the Popup Screen.

1.  **Preparation:** Open the app and spawn a foreground transaction using Developer Options -> `Simulate Known (Popup)`.
2.  **Action:** In the Popup Screen, tap a category (e.g., `Shopping`).
3.  **Verification 1:** Look below the "Auto-categorize" toggle. A new section titled **EXPENSE TYPE** should appear.
4.  **Verification 2:** You should see two chips: `Recurring` and `Flexible`.
5.  **Execution:** Tap `Recurring`, then tap **Confirm**.
6.  *Note: The system has now saved 'Shopping' as a recurring expense for this merchant.*

---

## Test Suite 4: The "Income vs. Expenses" Goal Settings

**Goal:** Verify the transparency and live math of the new Goal setting UI.

1.  **Preparation:** Navigate to Settings (gear icon) -> Step 3: Spending Goals -> `Set Monthly Limits`.
2.  **Action 1:** Locate the **TOTAL MONTHLY BUDGET** input field.
3.  **Execute:** Type `50000` into the field.
4.  **Verification 1:** Look at the blue "Safe to Spend" calculator widget below.
    *   "Total Budget" should instantly update to `₹50000`.
    *   "Fixed Bills" will show whatever the auto-detector (or your manual Test Suite 3) has classified as recurring (e.g., `- ₹0` or `- ₹X`).
    *   "Safe to Spend" will show the live result of `50000 - Fixed Bills`.
5.  **Action 2:** Tap **Save Goals**.

---

## Test Suite 5: Goal Onboarding Flow

**Goal:** Verify a new user is prompted for their Income/Budget immediately after setup.

1.  **Preparation:** Clear the app's storage (or tap `Developer Options -> Clear Data`).
2.  **Action 1:** Restart the app. You will see the initial API Setup screen.
3.  **Action 2:** Fill in your API key and tap **Start Tracking**.
4.  **Verification:** You should immediately be routed to the Goals Settings screen with the large header: *"What is your total monthly income or budget?"*. The input should be pre-filled with a smart default of `₹20000`.
5.  **Execute:** Tap **Continue** to reach the Home Screen.

---

## Test Suite 6: The "Burn Rate" Adaptive Insight

**Goal:** Verify the Rule Engine correctly calculates pacing against the "Safe to Spend" limit.

1.  **Preparation:** Ensure you have completed Test Suite 4 and set a Total Monthly Budget of `₹10,000`.
2.  **Action:** Spawn a massive fake transaction (e.g., `₹8,000`) for the current month and categorize it as `Flexible` (e.g., Food/Shopping).
3.  **Execute:** Navigate to the **Insights** tab. (Wait a moment for it to load/refresh).
4.  **Verification:** Look for a card with a 🔥 emoji titled **"Burn rate warning"**.
5.  **Check Copy:** The description should explicitly state: *"After your fixed payments... you have ₹X for flexible spending. At this pace you will exceed that by ₹Y."*
