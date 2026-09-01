# Insights Phase 2: Execution & Testing Plan

This document outlines the step-by-step implementation sequence, unit test specifications, and manual QA procedures to successfully deliver Phase 2: Rule Engine & Anomaly Detection.

## 1. Implementation Sequence

### Step 1: Data Models & State Modification
1.  **Create `InsightFinding` Model** (`lib/models/insight_finding.dart`):
    *   Fields: `id`, `emoji`, `title`, `description`, `trend` (enum: up, down, stable), `severity` (enum: low, medium, high).
2.  **Create `SavingsOpportunity` Model** (`lib/models/savings_opportunity.dart`):
    *   Fields: `id`, `emoji`, `title`, `description`, `potentialAmount` (String or double).
3.  **Update `InsightsSnapshot`** (`lib/models/insights_snapshot.dart`):
    *   Add `final List<InsightFinding> findings;`
    *   Add `final List<SavingsOpportunity> savingsOpportunities;`
    *   Update constructor and `empty()` factory.

### Step 2: Build `InsightsRuleEngine`
Create `lib/services/insights/insights_rule_engine.dart` containing purely deterministic, mathematical rules.

**Rule 1: Weekend Spike Detection**
*   *Logic:* Calculate average daily spend for weekdays vs. weekends over the last 30 days.
*   *Threshold:* If weekend daily average is > 150% of weekday average AND total weekend spend > ₹2000.
*   *Output:* High severity `InsightFinding`.

**Rule 2: Late-Night Spending Alert**
*   *Logic:* Sum transaction amounts between 10:00 PM and 4:00 AM over the last 30 days.
*   *Threshold:* If late-night spend > 20% of total spend AND > ₹1000.
*   *Output:* Medium severity `InsightFinding` highlighting late-night habit.

**Rule 3: Category Trend Alert (Discretionary)**
*   *Logic:* Compare current week vs previous week for categories like 'Food', 'Shopping', 'Fun'.
*   *Threshold:* If category spend increases by > 25% AND absolute increase > ₹500.
*   *Output:* `InsightFinding` with an `up` trend.

**Savings Evaluator 1: Frequency Cap on Food Delivery**
*   *Logic:* Count transactions for "Food" category where amount < ₹600 (typical delivery).
*   *Threshold:* If frequency > 6 times/month.
*   *Output:* `SavingsOpportunity` suggesting capping to 4 times/month. Calculation: `(current_frequency - 4) * avg_order_value`.

### Step 3: Service Orchestration
1.  Update `InsightsService.generateSnapshot()` to pass `allConfirmed` transactions into the `InsightsRuleEngine`.
2.  Assign the returned findings and opportunities to the `InsightsSnapshot`.

### Step 4: UI Integration
1.  **Refactor `InsightsScreen`**:
    *   Remove `_insights` and `_savingsOpportunities` hardcoded lists.
    *   Update `_buildInsightsSection` to map over `snapshot.findings`.
    *   Update `_buildSavingsOpportunitiesSection` to map over `snapshot.savingsOpportunities`.
    *   Handle empty states: If `findings.isEmpty`, hide the AI Behavioral Insights section or show a generic "No anomalies detected" card.

---

## 2. Unit Test Cases (`test/services/insights/insights_rule_engine_test.dart`)

| Test ID | Method/Rule | Setup | Execution | Expected Output |
| :--- | :--- | :--- | :--- | :--- |
| **UT-01** | `evaluateWeekendSpikes` | Mock 10 transactions. 8 on Sat/Sun totaling ₹4000. 2 on Mon/Tue totaling ₹500. | Call evaluator. | Returns 1 `InsightFinding` with `title` containing "Weekend" and `severity` High. |
| **UT-02** | `evaluateWeekendSpikes` | Mock 10 transactions. 5 on weekends totaling ₹1000. 5 on weekdays totaling ₹1000. | Call evaluator. | Returns empty list (0 findings). Threshold not met. |
| **UT-03** | `evaluateLateNight` | Mock 5 transactions. 4 at 11:30 PM, 1:00 AM totaling ₹3000. 1 at 2:00 PM totaling ₹500. | Call evaluator. | Returns 1 `InsightFinding` about Late Night spending. |
| **UT-04** | `evaluateCategoryTrends`| Mock 20 transactions. Current week 'Food' = ₹2000. Prev week 'Food' = ₹1000. | Call evaluator. | Returns 1 `InsightFinding` with `trend: up` and `emoji: 🍔`. |
| **UT-05** | `generateSavings` | Mock 15 'Food' transactions of ₹300 each in the last 30 days. | Call evaluator. | Returns 1 `SavingsOpportunity` calculating savings of `(15 - 4) * 300 = ₹3300`. |
| **UT-06** | `generateSavings` | Mock 2 'Food' transactions in the last 30 days. | Call evaluator. | Returns empty list. (Healthy behavior). |

---

## 3. Manual QA & Developer Test Cases

These tests validate the end-to-end integration through the UI, ensuring `AppState` and UI reactivity function correctly.

### **QA-01: Baseline Empty State**
*   **Prerequisite:** App database is cleared (Developer Tools -> Clear All Transactions).
*   **Action:** Open Insights screen.
*   **Expected:** "Your spending patterns are still being understood" card is visible. "AI Behavioral Insights" and "Savings Opportunities" sections are hidden.

### **QA-02: Weekend Spike Trigger & UI Render**
*   **Prerequisite:** Database cleared.
*   **Action:** 
    1. Open `DeveloperToolsScreen` (if we need to, we can add a specific "Inject Weekend Spike" button to the tools).
    2. Alternatively, manually add 5 transactions of ₹1000 each with weekend timestamps using a test script.
    3. Navigate to Insights screen.
*   **Expected:** 
    *   The "AI Behavioral Insights" section appears.
    *   A card titled "Weekend spending spikes" appears with an upward trend badge.

### **QA-03: Savings Opportunity Trigger**
*   **Prerequisite:** Database cleared.
*   **Action:** Inject 10 transactions of ₹250 categorized as "Food" over the last 30 days.
*   **Expected:** 
    *   The "Savings Opportunities" section appears.
    *   A card suggests "Reduce food delivery" with a calculated potential saving (e.g., "Save ₹1,500/month").

### **QA-04: Graceful Degradation (Below Thresholds)**
*   **Prerequisite:** Database cleared.
*   **Action:** Inject a normal, healthy spread of transactions (e.g., ₹200 daily across mixed categories).
*   **Expected:** 
    *   Charts and Health Score populate correctly (from Phase 1).
    *   The "AI Behavioral Insights" section either hides or displays a positive reinforcement card ("Your spending is highly consistent").
    *   "Savings Opportunities" section is hidden.