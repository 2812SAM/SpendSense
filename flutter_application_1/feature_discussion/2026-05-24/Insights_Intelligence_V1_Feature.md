# Insights Intelligence V1 Feature Plan

## 1. Feature Summary
Build a reactive, explainable insights system for SpendSense that helps individual students and bachelor users improve habits through financial coaching and awareness. The system must operate only on locally stored, confirmed transactions and should convert deterministic metrics into AI-generated narratives with evidence-backed reasoning.

## 2. Product Vision
- Primary outcome: better retention, better review completion, more accurate categorization, and stronger user trust.
- Product posture: reactive coaching, not predictive planning.
- UX posture: evidence first, narrative second.
- Data posture: local SQLite is the source of truth for V1.

## 3. Final Goal
Turn the insights page into a trustworthy personal spending coach that:
- shows real charts and category trends from actual user behavior
- highlights anomalies and habit changes
- surfaces strong-evidence savings opportunities
- explains patterns with clear evidence
- assigns a stable formula-based financial health score

## 4. Core Constraints
- Use only `is_confirmed = 1` transactions.
- Use local SQLite only for V1.
- Use AI only after deterministic metrics and findings are computed.
- Keep anomaly alerts only on the insights page.
- Keep the system reactive, not proactive.
- Keep income-aware insights out of scope for now, with a dummy-compatible future path.

## 5. Global In Scope
- Real charts from confirmed transactions
- Category trends
- Spending pattern analysis
- Strong-evidence savings suggestions
- Reactive anomaly alerts
- Formula-based financial health score
- AI-generated explanations/narratives from computed metrics
- Immediate category-description capture for custom categories

## 6. Global Out of Scope
- Income tracking
- Budgeting
- Investments
- Loans as a first-class insights dimension
- Multi-account analysis
- Predictive ML
- Push-notification-based insights
- Google Sheets as a primary analytics source

## 7. Assumptions
- Insights page should be recent-behavior-first, because the product goal is coaching and habit change.
- User-defined categories may be ambiguous, so the system should capture category descriptions at creation time and use them during insights interpretation.
- If AI is unavailable, the insights page must still function with rule-based fallback text.

## 8. Execution Workflow
1. Confirmed transactions are read from local SQLite.
2. Transactions are normalized into analysis windows.
3. Metrics are computed deterministically.
4. Rule engine converts metrics into structured findings.
5. Financial health score is calculated using a stable formula.
6. AI receives only computed findings and metrics, not raw free-form history.
7. AI returns narratives, coaching text, and evidence-backed explanations.
8. UI renders:
   - hero score
   - charts
   - dynamic findings
   - anomalies
   - savings opportunities
9. Fallback rendering is used if:
   - there is insufficient data
   - AI is unavailable
   - findings confidence is too weak

## 9. Proposed Technical Architecture
- `InsightsService`
  - Orchestrates snapshot generation for the page.
- `InsightsMetricsEngine`
  - Computes deterministic metrics from confirmed transactions.
- `InsightsRuleEngine`
  - Converts metrics into structured insight findings.
- `InsightsNarrativeService`
  - Uses AI to produce explanations from structured findings.
- `CategoryMetadataService`
  - Stores and retrieves user descriptions for custom categories.

## 10. Proposed File Additions
- `lib/models/insights_snapshot.dart`
- `lib/models/insight_finding.dart`
- `lib/models/category_metadata.dart`
- `lib/services/insights/insights_service.dart`
- `lib/services/insights/insights_metrics_engine.dart`
- `lib/services/insights/insights_rule_engine.dart`
- `lib/services/insights/insights_narrative_service.dart`
- `lib/services/category_metadata_service.dart`

## 11. Proposed Data Additions
### 11.1 New Local Table: `category_metadata`
- `category_name TEXT PRIMARY KEY`
- `description TEXT NOT NULL`
- `created_at INTEGER NOT NULL`
- `updated_at INTEGER NOT NULL`

### 11.2 Future-Compatible Optional Table: `insights_cache`
Not required in V1, but can be added later for performance if snapshot generation becomes heavy.

## 12. Sub-Feature Plan

---

## Sub-Feature 1: Insights Data Foundation

### Goal
Create a stable insights data pipeline that reads only confirmed transactions and returns one typed snapshot for the UI.

### In Scope
- Load confirmed transactions from SQLite
- Support windows:
  - last 7 days
  - last 30 days
  - month-to-date
  - week-over-week
  - month-over-month
- Normalize output into a single `InsightsSnapshot`

### Plan
1. Create `InsightsService`.
2. Read confirmed transactions through `LocalStorageService`.
3. Normalize transactions into reusable analysis windows.
4. Define typed snapshot models for the insights screen.
5. Keep snapshot generation independent from UI widgets.

### Expected Criteria
- Snapshot generation is deterministic.
- Only confirmed transactions are included.
- Empty and low-data users still receive a valid snapshot object.

### Acceptance Criteria
1. A single service call can build the entire insights snapshot.
2. No pending or low-confidence transaction is included.
3. Time windows are computed consistently across the page.
4. Empty-state users do not crash the insights flow.

---

## Sub-Feature 2: Custom Category Description Capture

### Goal
Capture useful semantic context for user-defined categories so insights can interpret custom labels accurately.

### In Scope
- Prompt for free-text description immediately when a custom category is created
- Store description locally
- Make descriptions available to the insights engine and AI narrative layer

### Plan
1. Add `category_metadata` storage.
2. Update custom-category creation flow to collect description at creation time.
3. Add read/write APIs through `CategoryMetadataService`.
4. Feed category descriptions into rule interpretation and AI prompt context.

### Expected Criteria
- Category descriptions are optional for the app to function, but required for the custom-category creation flow in V1.
- Insights can use descriptions without modifying historical transactions.

### Acceptance Criteria
1. Creating a custom category prompts for a description.
2. Description is stored locally and survives app restarts.
3. Insights services can retrieve the description for custom categories.
4. No existing category-management behavior regresses.

---

## Sub-Feature 3: Metrics Engine

### Goal
Compute the quantitative signals needed to power charts, score, findings, and savings opportunities.

### In Scope
- Daily spend totals
- Weekly and monthly spend trends
- Category totals and concentration
- Weekday vs weekend analysis
- Late-night spending analysis
- Spending consistency analysis
- Merchant recurrence analysis
- Baseline comparison windows for anomalies

### Plan
1. Create `InsightsMetricsEngine` as a pure computation layer.
2. Build reusable metric helpers around transactions and time windows.
3. Compute:
   - total spend by day
   - total spend by category
   - WoW delta
   - MoM delta
   - weekend ratio
   - late-night ratio
   - top-category concentration
   - anomaly baselines
4. Return structured metrics with evidence fields.

### Expected Criteria
- Metric outputs are reproducible from the same transaction set.
- Metric definitions are explicit and testable.
- Comparison windows are attached to every metric that drives a finding.

### Acceptance Criteria
1. Weekly chart data can be produced from real local transactions.
2. Monthly trend data can be produced from real local transactions.
3. Category totals align with transaction sums.
4. Weekday/weekend and late-night metrics are calculable for any user with enough data.
5. All metrics used by score and findings are covered by tests.

---

## Sub-Feature 4: Insights Rule Engine

### Goal
Convert raw metrics into dynamic, evidence-backed insights and anomalies based on strong thresholds.

### In Scope
- Dynamic findings based on available evidence
- Strong-evidence savings suggestions only
- Anomaly detection
- Pattern recognition for habit change

### Plan
1. Create `InsightsRuleEngine`.
2. Encode rule families:
   - weekend spike
   - reduced food delivery
   - late-night spend increase
   - consistent daily spend
   - anomaly frequency
   - impulse-category concentration
   - strong merchant/category spike
3. Each rule should output:
   - finding id
   - evidence block
   - severity
   - recommendation type
   - comparison window used
4. Return a dynamic list sorted by relevance and evidence strength.

### Expected Criteria
- No weak or speculative findings should be shown.
- Every finding must carry evidence values.
- The engine should support a variable number of insight cards.

### Acceptance Criteria
1. Findings are generated only when thresholds are met.
2. Each finding includes explicit evidence and comparison window metadata.
3. The number of insight cards is dynamic based on available findings.
4. Anomalies are included only on the insights page.
5. Savings suggestions appear only when evidence is strong.

---

## Sub-Feature 5: Financial Health Score

### Goal
Introduce a stable and explainable formula-based score mixing savings behavior, spending discipline, and pattern quality.

### In Scope
- Positive score inputs:
  - lower weekend spikes
  - reduced food delivery
  - lower anomaly frequency
  - consistent daily spend
- Negative score inputs:
  - repeated anomalies
  - high late-night spend
  - heavy concentration in impulse categories

### Plan
1. Define score components with fixed weights.
2. Normalize each component to a bounded range.
3. Produce:
   - total score
   - component breakdown
   - score band label
4. Keep formula transparent and versionable.

### Expected Criteria
- Score should be stable across repeated runs.
- Score should not depend on AI.
- Score should be decomposable for debug and future explanation.

### Acceptance Criteria
1. Score is computed locally without AI.
2. Score is reproducible from the same transaction history.
3. Score includes component breakdown for internal use.
4. Score label mapping is deterministic.
5. UI can render both score and score-status label.

---

## Sub-Feature 6: AI Narrative Generation

### Goal
Transform structured findings into helpful, human-sounding coaching narratives without letting AI invent the analytics.

### In Scope
- AI-generated explanation text
- AI-generated coaching suggestions
- AI-generated savings framing
- Evidence-based comparison wording
- Rule-based fallback when no API key exists

### Plan
1. Create `InsightsNarrativeService`.
2. Feed AI:
   - structured findings
   - metric evidence
   - category descriptions where available
   - allowed tone/style constraints
3. Ask AI to return:
   - short title
   - concise explanation
   - evidence phrasing
   - coaching suggestion
4. Add fallback local templates when AI is unavailable.

### Expected Criteria
- AI never becomes the source of truth for calculations.
- Explanations always reference evidence.
- Fallback works even with no API key.

### Acceptance Criteria
1. Insights page works without AI key.
2. With AI enabled, explanations are generated from structured findings only.
3. Each explanation references a comparison window or evidence metric.
4. No raw transaction dump is required in prompts.
5. Generated text stays aligned with a coaching-and-awareness tone.

---

## Sub-Feature 7: Insights UI Wiring

### Goal
Replace hardcoded mock content on the insights page with real snapshot-driven content.

### In Scope
- Hero score
- Weekly and monthly charts
- Dynamic findings list
- Category trends
- Savings opportunities
- Empty and low-data states

### Plan
1. Keep the current visual direction but wire each section to `InsightsSnapshot`.
2. Render only sections supported by data availability.
3. Support dynamic finding count.
4. Show explicit empty-state and low-data messaging.
5. Keep chart tooltips interactive.

### Expected Criteria
- UI reflects real user data.
- Screen remains usable with very little historical data.
- Dynamic findings do not break layout.

### Acceptance Criteria
1. Insights page no longer depends on hardcoded analytics data.
2. Charts reflect local confirmed transaction history.
3. Top categories come from computed category totals.
4. Dynamic findings render correctly for zero, few, or many findings.
5. Low-data users see a graceful fallback instead of misleading analytics.

---

## Sub-Feature 8: Empty, Low-Data, and Fallback States

### Goal
Make the feature trustworthy for users with little history or missing AI setup.

### In Scope
- No-transaction state
- Low-data state
- No-AI-key fallback
- Weak-evidence suppression

### Plan
1. Define minimum thresholds per feature:
   - chart thresholds
   - anomaly thresholds
   - suggestion thresholds
2. Hide or soften sections when data is insufficient.
3. Use fallback local copy when AI is unavailable.
4. Distinguish between:
   - no data
   - not enough data yet
   - AI unavailable

### Expected Criteria
- Users should never see fake confidence from weak data.
- Feature should remain useful even without AI.

### Acceptance Criteria
1. New users get a useful empty or low-data experience.
2. Weak findings are not shown.
3. Missing API keys do not block the page.
4. Fallback messages communicate why certain insights are unavailable.

---

## Sub-Feature 9: Testing and Verification

### Goal
Make insights logic safe enough to trust before product rollout.

### In Scope
- Unit tests for metrics
- Unit tests for rules
- Unit tests for score
- Regression tests for category metadata capture
- Manual QA checklist for UI states

### Plan
1. Add deterministic fixture datasets.
2. Test all supported time windows.
3. Test each rule with positive and negative cases.
4. Test score stability.
5. Test fallback behavior with no AI key.

### Expected Criteria
- Metrics and findings should be testable without widget rendering.
- QA should be able to validate findings against known fixture data.

### Acceptance Criteria
1. Metrics engine has unit coverage for main windows and aggregations.
2. Rule engine has coverage for each supported finding family.
3. Score formula has deterministic test coverage.
4. Fallback narrative path is tested.
5. Custom category description flow is verified end to end.

## 13. Rule Families for V1
- Weekend spending spike
- Reduced food delivery
- Late-night spending increase
- Strong impulse-category concentration
- Consistent daily spending
- Category spike versus 30-day baseline
- Merchant burst anomaly
- Lower anomaly frequency improvement

## 14. Suggested Score Components for V1
- Weekend discipline: 25%
- Food delivery control: 20%
- Spend consistency: 20%
- Anomaly frequency: 20%
- Impulse concentration penalty: 15%

This formula is a starting draft and should be tuned after fixture testing.

## 15. Delivery Phases
### Phase 1
- Data foundation
- Metrics engine
- Charts and categories wired to real data

### Phase 2
- Rule engine
- Anomaly detection
- Savings opportunities

### Phase 3
- Financial health score
- AI narratives
- Fallback states and polishing

### Phase 4
- Test hardening
- Threshold tuning
- UX refinement

## 16. Verification Checklist
- Confirmed-only filter works
- Weekly chart matches known fixture data
- Monthly trend matches known fixture data
- Top categories align with transaction sums
- Dynamic findings vary correctly by evidence
- Savings suggestions appear only with strong evidence
- Score remains stable across runs
- AI fallback works without API key
- Custom category description is captured and retrievable
- Empty-state and low-data-state UX are clear

## 17. Risks and Watchouts
- Category vocabulary drift can distort analytics if not normalized or described well.
- Very low-data users may produce misleading signals unless thresholds are strict.
- AI can overstate findings if the prompt is not tightly bounded to evidence.
- Heavy logic in widgets will make testing hard; keep engines pure.
- If confirmed transactions are sparse, insight density will be low; the UI must handle that gracefully.

## 18. Recommended Next Implementation Order
1. Add `category_metadata` storage and capture flow.
2. Build `InsightsSnapshot` model.
3. Build `InsightsMetricsEngine`.
4. Wire charts and categories to real computed data.
5. Build `InsightsRuleEngine`.
6. Add savings-opportunity and anomaly sections.
7. Add financial health score.
8. Add `InsightsNarrativeService` with fallback.
9. Add tests and threshold tuning.
