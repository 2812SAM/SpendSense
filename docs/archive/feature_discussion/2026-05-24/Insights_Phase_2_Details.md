# Insights Phase 2: Rule Engine & Anomaly Detection Detailed Plan

## 1. Overview
Phase 2 bridges the gap between raw metrics (Phase 1) and AI-generated narratives (Phase 3). It focuses on building the `InsightsRuleEngine` to systematically analyze the metrics computed by `InsightsMetricsEngine` and generate structured `InsightFinding` objects. This phase covers pattern recognition, anomaly detection, and savings opportunity identification.

## 2. Goals & Expectations
*   **Deterministic Findings:** The rule engine must rely on strict mathematical thresholds, not AI interpretation. If a user's data hits the threshold, the finding is generated.
*   **Strong Evidence Only:** We will only surface findings backed by clear evidence (e.g., "Food delivery spend increased by 20% compared to a 30-day baseline"). No weak or speculative findings.
*   **Anomaly Detection:** Identify sudden spikes in specific categories or merchants outside normal behavior.
*   **Savings Opportunities:** Highlight clear areas where small habit changes yield quantifiable savings (e.g., "Cutting weekend dining to once a week saves ₹X").
*   **Dynamic UI Integration:** The UI must reactively display these findings and opportunities.

## 3. Scope of Implementation

### 3.1 Data Models
*   Create `InsightFinding` model (id, title, description, severity, evidence, category/merchant reference).
*   Create `SavingsOpportunity` model (id, title, description, potentialAmount).

### 3.2 Rule Engine (`InsightsRuleEngine`)
Implement specific rule evaluators:
1.  **Weekend Spending Spike:** Compares weekend avg vs weekday avg.
2.  **Category Trend Alert:** Detects significant MoM or WoW increases in discretionary categories (e.g., Food, Shopping).
3.  **Late-Night Spikes:** Identifies high spend ratios between 10 PM and 4 AM.
4.  **Recurring Subscription/Merchant Anomaly:** Identifies unusual spikes for a specific merchant compared to its historical average.

### 3.3 Savings Evaluators
1.  **Discretionary Reduction:** Calculate potential savings by capping the highest discretionary category to a historical lower bound.
2.  **Frequency Cap:** Calculate savings by reducing the frequency of specific high-volume, low-amount merchants (e.g., Swiggy/Zomato).

### 3.4 Service Integration
*   Update `InsightsService` to invoke `InsightsRuleEngine`.
*   Pass the generated findings and opportunities into the `InsightsSnapshot`.

### 3.5 UI Wiring
*   Update `InsightsScreen` to render the `_buildInsightsSection` and `_buildSavingsOpportunitiesSection` using the live data from `InsightsSnapshot` instead of mock data.

## 4. Acceptance Criteria

1.  **Rule Execution:** `InsightsRuleEngine` processes a list of transactions and returns a list of `InsightFinding` objects.
2.  **Threshold Strictness:** Findings are *only* generated if the defined severity thresholds (e.g., > 15% deviation) are met.
3.  **UI Rendering:** The Insights screen displays the generated findings in the "AI Behavioral Insights" (temporary label) section.
4.  **Savings Display:** The Insights screen displays calculated savings opportunities.
5.  **Empty State Handling:** If no rules trigger (normal behavior), the UI handles the empty state gracefully without crashing or showing empty cards.
6.  **Performance:** Rule evaluation runs efficiently without blocking the main UI thread (should complete in < 50ms for typical local datasets).

## 5. Test Cases (To be implemented during development)

### 5.1 Unit Tests (`test/services/insights/insights_rule_engine_test.dart`)

*   **TC-R01: Weekend Spike Detection**
    *   *Input:* Dataset with 80% spend on weekends, 20% on weekdays.
    *   *Expected:* Engine returns a finding for "Weekend spending spike" with High severity.
*   **TC-R02: Category Trend Ignored on Essential Categories**
    *   *Input:* 50% increase in 'Rent'.
    *   *Expected:* Engine does *not* generate a finding (Rent is non-discretionary).
*   **TC-R03: Category Trend Detected on Discretionary**
    *   *Input:* 30% increase in 'Food' WoW.
    *   *Expected:* Engine returns a finding for "Food category increase".
*   **TC-R04: Late Night Spending Alert**
    *   *Input:* Multiple transactions between 11 PM and 2 AM.
    *   *Expected:* Engine returns a finding highlighting late-night habits.
*   **TC-S01: Savings Opportunity Generation**
    *   *Input:* High frequency (10+ times/month) food delivery orders.
    *   *Expected:* Engine returns a `SavingsOpportunity` suggesting a reduction to 4 times/month with calculated potential savings.
*   **TC-E01: Empty Findings**
    *   *Input:* Consistent, low-variance dataset across all categories and days.
    *   *Expected:* Engine returns empty lists for findings and opportunities.

## 6. Post-Implementation Validation Plan

### 6.1 Developer Validation (Manual)
1.  **Inject Spikes:** Use the `DeveloperToolsScreen` to inject multiple high-value transactions for a specific category (e.g., 'Food') on a weekend date.
2.  **Verify UI:** Navigate to Insights. Confirm the "Weekend spending spike" or "Food category increase" finding appears.
3.  **Verify Savings:** Confirm a corresponding savings opportunity is generated.
4.  **Clear DB:** Use "Clear All Transactions" in Developer Tools.
5.  **Verify Reset:** Navigate to Insights. Confirm findings and opportunities are cleared.

### 6.2 Edge Case Validation
1.  **Insufficient Data:** Run the engine with only 1 or 2 transactions. Verify no erratic findings (like "infinity%" increases) are generated.
2.  **Zero Value Transactions:** Ensure the engine handles `0` amount transactions (if any exist) without division-by-zero errors.

## 7. Next Steps to Start Phase 2
1.  Create `lib/models/insight_finding.dart` and `lib/models/savings_opportunity.dart`.
2.  Add `List<InsightFinding>` and `List<SavingsOpportunity>` to `InsightsSnapshot`.
3.  Create `lib/services/insights/insights_rule_engine.dart` and implement the base logic.
4.  Wire it into `InsightsService.generateSnapshot()`.