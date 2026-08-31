Phase 2.5 Implementation Plan: Goal-Driven Adaptive Engine
(Updated: Expense Classification System included)
Context
Flutter app, Provider state management, sqflite for local storage
Phase 2 (InsightsRuleEngine) is live and working
Single user, no multi-profile support needed
Two expense types: `recurring` (rent, EMIs, bills) and `sometime` (haircuts, shopping, food)
All milestones ship together on a single feature branch
---
M1: Database Schema & Migration
Action: bump DB version by 1 in `DatabaseHelper`
```dart
version: _dbVersion, // increment by 1
onUpgrade: (db, oldVersion, newVersion) async {
  if (oldVersion < newVersion) {

    // Table 1: user monthly goal
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_goals (
        id INTEGER PRIMARY KEY DEFAULT 1,
        monthly_total_limit REAL NOT NULL DEFAULT 0,
        last_updated TEXT NOT NULL
      )
    ''');

    // Table 2: per-category goals
    await db.execute('''
      CREATE TABLE IF NOT EXISTS category_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_name TEXT NOT NULL UNIQUE,
        monthly_limit REAL NOT NULL DEFAULT 0,
        last_updated TEXT NOT NULL
      )
    ''');

    // Table 3: expense classifications
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expense_classifications (
        merchant_or_category TEXT PRIMARY KEY,
        nature TEXT NOT NULL CHECK(nature IN ("recurring","sometime")),
        expected_amount REAL,
        user_confirmed INTEGER NOT NULL DEFAULT 0,
        last_updated TEXT NOT NULL
      )
    ''');

    // Seed default goal row so existing users never read null
    await db.execute(
      "INSERT OR IGNORE INTO user_goals VALUES (1, 0, datetime('now'))"
    );
  }
},
```
Schema rules:
`user_goals` always has exactly one row (`id = 1`). Never insert a second row.
`category_goals` uses `INSERT OR REPLACE` on `category_name`.
`expense_classifications` uses `merchant_or_category` as the key (e.g. `'Rent'`, `'Jio'`, `'Food'`).
`expected_amount` is `NULL` for variable recurring bills (electricity, water). Not null for truly fixed ones (rent, EMI).
`user_confirmed = 0` means auto-detected. `user_confirmed = 1` means user explicitly set it.
---
M2: Data Models + Repositories
Create `lib/models/user_goals.dart`
```dart
class UserGoals {
  final double monthlyTotalLimit;
  final Map<String, double> categoryLimits;

  const UserGoals({
    required this.monthlyTotalLimit,
    required this.categoryLimits,
  });

  factory UserGoals.empty() =>
      const UserGoals(monthlyTotalLimit: 0, categoryLimits: {});
}
```
Create `lib/models/expense_classification.dart`
```dart
enum ExpenseNature { recurring, sometime }

class ExpenseClassification {
  final String merchantOrCategory;
  final ExpenseNature nature;
  final double? expectedAmount; // null = variable recurring
  final bool userConfirmed;

  const ExpenseClassification({
    required this.merchantOrCategory,
    required this.nature,
    this.expectedAmount,
    this.userConfirmed = false,
  });
}
```
Create `lib/repositories/goals_repository.dart`
```dart
class GoalsRepository {
  final Database db;
  GoalsRepository(this.db);

  Future<UserGoals> getGoals() async {
    final totalRow = await db.query('user_goals', where: 'id = 1', limit: 1);
    final categoryRows = await db.query('category_goals');

    final monthlyLimit = totalRow.isEmpty
        ? 0.0
        : (totalRow.first['monthly_total_limit'] as num).toDouble();

    final categoryLimits = {
      for (final row in categoryRows)
        row['category_name'] as String:
            (row['monthly_limit'] as num).toDouble()
    };

    return UserGoals(monthlyTotalLimit: monthlyLimit, categoryLimits: categoryLimits);
  }

  Future<void> setMonthlyLimit(double limit) async {
    await db.update(
      'user_goals',
      {'monthly_total_limit': limit, 'last_updated': DateTime.now().toIso8601String()},
      where: 'id = 1',
    );
  }

  Future<void> setCategoryLimit(String category, double limit) async {
    await db.insert(
      'category_goals',
      {
        'category_name': category,
        'monthly_limit': limit,
        'last_updated': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
```
Create `lib/repositories/classification_repository.dart`
```dart
class ClassificationRepository {
  final Database db;
  ClassificationRepository(this.db);

  Future<List<ExpenseClassification>> getAll() async {
    final rows = await db.query('expense_classifications');
    return rows.map((row) => ExpenseClassification(
      merchantOrCategory: row['merchant_or_category'] as String,
      nature: (row['nature'] as String) == 'recurring'
          ? ExpenseNature.recurring
          : ExpenseNature.sometime,
      expectedAmount: row['expected_amount'] != null
          ? (row['expected_amount'] as num).toDouble()
          : null,
      userConfirmed: (row['user_confirmed'] as int) == 1,
    )).toList();
  }

  Future<void> save(ExpenseClassification c) async {
    await db.insert(
      'expense_classifications',
      {
        'merchant_or_category': c.merchantOrCategory,
        'nature': c.nature.name,
        'expected_amount': c.expectedAmount,
        'user_confirmed': c.userConfirmed ? 1 : 0,
        'last_updated': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveAll(List<ExpenseClassification> classifications) async {
    final batch = db.batch();
    for (final c in classifications) {
      batch.insert(
        'expense_classifications',
        {
          'merchant_or_category': c.merchantOrCategory,
          'nature': c.nature.name,
          'expected_amount': c.expectedAmount,
          'user_confirmed': c.userConfirmed ? 1 : 0,
          'last_updated': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}
```
---
M3: Auto-Detection Service
Create `lib/services/classification_detector.dart`
This runs once silently on app launch. It reads existing transaction history and proposes classifications without asking the user anything.
```dart
class ClassificationDetector {
  /// Returns auto-detected classifications for review.
  /// Does NOT write to DB — caller decides whether to save.
  List<ExpenseClassification> detect(List<Transaction> history) {
    final results = <ExpenseClassification>[];

    // Group transactions by category
    final byCategory = <String, List<Transaction>>{};
    for (final t in history) {
      byCategory.putIfAbsent(t.category, () => []).add(t);
    }

    for (final entry in byCategory.entries) {
      final category = entry.key;
      final txns = entry.value;

      if (_isLikelyRecurring(txns)) {
        final amounts = txns.map((t) => t.amount).toList();
        final avg = amounts.reduce((a, b) => a + b) / amounts.length;
        final variance = amounts.map((a) => (a - avg).abs()).reduce((a, b) => a + b) / amounts.length;
        final isFixed = variance < avg * 0.05; // less than 5% variance = fixed amount

        results.add(ExpenseClassification(
          merchantOrCategory: category,
          nature: ExpenseNature.recurring,
          expectedAmount: isFixed ? avg : null, // null for variable like electricity
          userConfirmed: false,
        ));
      }
      // else: default is 'sometime', no need to store (engine uses sometime as fallback)
    }

    return results;
  }

  bool _isLikelyRecurring(List<Transaction> txns) {
    if (txns.length < 2) return false;

    // Check if transaction appears in at least 2 different months
    final months = txns.map((t) => '${t.date.year}-${t.date.month}').toSet();
    return months.length >= 2;
  }
}
```
---
M4: ClassificationProvider
Create `lib/providers/classification_provider.dart`
```dart
class ClassificationProvider extends ChangeNotifier {
  final ClassificationRepository _repo;
  final ClassificationDetector _detector;
  List<ExpenseClassification> _classifications = [];
  List<ExpenseClassification> _pendingConfirmation = []; // auto-detected, not yet confirmed

  ClassificationProvider(this._repo, this._detector);

  List<ExpenseClassification> get classifications => _classifications;
  List<ExpenseClassification> get pendingConfirmation => _pendingConfirmation;
  bool get hasPendingConfirmations => _pendingConfirmation.isNotEmpty;

  Future<void> init(List<Transaction> transactionHistory) async {
    _classifications = await _repo.getAll();

    // Only run auto-detection if we have no confirmed classifications yet
    final hasConfirmed = _classifications.any((c) => c.userConfirmed);
    if (!hasConfirmed) {
      final detected = _detector.detect(transactionHistory);
      // Only surface ones not already classified
      final existingKeys = _classifications.map((c) => c.merchantOrCategory).toSet();
      _pendingConfirmation = detected
          .where((d) => !existingKeys.contains(d.merchantOrCategory))
          .toList();
    }

    notifyListeners();
  }

  ExpenseNature natureOf(String categoryOrMerchant) {
    final match = _classifications
        .where((c) => c.merchantOrCategory == categoryOrMerchant)
        .firstOrNull;
    return match?.nature ?? ExpenseNature.sometime; // default: sometime
  }

  double? expectedAmountOf(String categoryOrMerchant) {
    return _classifications
        .where((c) => c.merchantOrCategory == categoryOrMerchant)
        .firstOrNull
        ?.expectedAmount;
  }

  /// Called when user confirms auto-detected suggestions from the confirmation card
  Future<void> confirmDetected(List<ExpenseClassification> confirmed) async {
    final toSave = confirmed.map((c) => ExpenseClassification(
      merchantOrCategory: c.merchantOrCategory,
      nature: c.nature,
      expectedAmount: c.expectedAmount,
      userConfirmed: true,
    )).toList();
    await _repo.saveAll(toSave);
    _classifications = [..._classifications, ...toSave];
    _pendingConfirmation = [];
    notifyListeners();
  }

  /// Called from transaction detail screen or goals settings
  Future<void> setClassification(
    String merchantOrCategory,
    ExpenseNature nature, {
    double? expectedAmount,
  }) async {
    final c = ExpenseClassification(
      merchantOrCategory: merchantOrCategory,
      nature: nature,
      expectedAmount: expectedAmount,
      userConfirmed: true,
    );
    await _repo.save(c);
    _classifications = [
      ..._classifications.where((e) => e.merchantOrCategory != merchantOrCategory),
      c,
    ];
    notifyListeners();
  }

  /// Dismiss the confirmation card without confirming
  void dismissPendingConfirmation() {
    _pendingConfirmation = [];
    notifyListeners();
  }
}
```
---
M5: GoalsProvider
Create `lib/providers/goals_provider.dart`
```dart
class GoalsProvider extends ChangeNotifier {
  final GoalsRepository _repo;
  UserGoals _goals = UserGoals.empty();

  GoalsProvider(this._repo) { _load(); }

  UserGoals get currentGoals => _goals;

  Future<void> _load() async {
    _goals = await _repo.getGoals();
    notifyListeners();
  }

  Future<void> updateMonthlyLimit(double limit) async {
    await _repo.setMonthlyLimit(limit);
    _goals = UserGoals(monthlyTotalLimit: limit, categoryLimits: _goals.categoryLimits);
    notifyListeners();
  }

  Future<void> updateCategoryLimit(String category, double limit) async {
    await _repo.setCategoryLimit(category, limit);
    final updated = Map<String, double>.from(_goals.categoryLimits)..[category] = limit;
    _goals = UserGoals(monthlyTotalLimit: _goals.monthlyTotalLimit, categoryLimits: updated);
    notifyListeners();
  }
}
```
---
M6: InsightsRuleEngine Refactor
Update method signature
```dart
// Before
List<Insight> evaluateRules(List<Transaction> transactions) { }

// After
List<Insight> evaluateRules(
  List<Transaction> transactions,
  UserGoals goals,
  ClassificationProvider classifications,
) { }
```
Split transactions at the top of evaluateRules
```dart
final sometimeTransactions = transactions
    .where((t) => classifications.natureOf(t.category) == ExpenseNature.sometime)
    .toList();

final recurringTransactions = transactions
    .where((t) => classifications.natureOf(t.category) == ExpenseNature.recurring)
    .toList();
```
All 3 existing rules run only on `sometimeTransactions`.
Rule 1: Habitual Overspend (sometime only)
```dart
for (final entry in goals.categoryLimits.entries) {
  final category = entry.key;
  final goal = entry.value;
  if (goal == 0) continue;

  // Only check sometime transactions for this category
  final categoryTxns = sometimeTransactions
      .where((t) => t.category == category)
      .toList();

  final avg3Month = _getAverage3MonthSpend(categoryTxns);

  if (avg3Month > goal * 1.1) {
    insights.add(Insight(
      severity: Severity.high,
      message: 'You consistently spend ₹${(avg3Month - goal).toStringAsFixed(0)} '
               'above your $category target. This is a recurring pattern.',
    ));
  }
}
```
Rule 2: Burn Rate Warning (sometime only)
```dart
if (goals.monthlyTotalLimit > 0) {
  final today = DateTime.now();
  final dayOfMonth = today.day;
  final daysInMonth = DateUtils.getDaysInMonth(today.year, today.month);

  // Only count sometime spend for burn rate — recurring is pre-committed, not variable
  final sometimeSpend = _getCurrentMonthTotal(sometimeTransactions);
  final recurringCommitted = _getCurrentMonthTotal(recurringTransactions);
  final effectiveLimit = goals.monthlyTotalLimit - recurringCommitted;

  final projected = (sometimeSpend / dayOfMonth) * daysInMonth;

  if (projected > effectiveLimit) {
    insights.add(Insight(
      severity: Severity.medium,
      message: 'After your fixed payments (₹${recurringCommitted.toStringAsFixed(0)}), '
               'you have ₹${effectiveLimit.toStringAsFixed(0)} for flexible spending. '
               'At this pace you will exceed that by ₹${(projected - effectiveLimit).toStringAsFixed(0)}.',
    ));
  }
}
```
Rule 3: Safe Anomaly (sometime only)
```dart
final spikeDetected = _detectWeekendSpike(sometimeTransactions);
final sometimeSpend = _getCurrentMonthTotal(sometimeTransactions);
final recurringCommitted = _getCurrentMonthTotal(recurringTransactions);
final effectiveLimit = goals.monthlyTotalLimit - recurringCommitted;

if (spikeDetected && effectiveLimit > 0 && sometimeSpend < effectiveLimit * 0.8) {
  insights.add(Insight(
    severity: Severity.low,
    message: 'You had a high-spend period, but you\'re still well within '
             'your flexible budget. You\'re on track!',
  ));
}
```
Rule 4: Recurring Expense Anomaly (recurring only)
```dart
for (final t in recurringTransactions) {
  final expected = classifications.expectedAmountOf(t.category);
  if (expected == null) continue; // variable recurring — skip amount check

  final diff = t.amount - expected;
  if (diff.abs() > expected * 0.05) {
    insights.add(Insight(
      severity: Severity.medium,
      message: '${t.category} payment this month is '
               '₹${diff.abs().toStringAsFixed(0)} ${diff > 0 ? "higher" : "lower"} than usual.',
    ));
  }
}
```
Fallback: no goals set yet
```dart
// At the top of evaluateRules — if user has set no goals, run Phase 2 logic unchanged
if (goals.monthlyTotalLimit == 0 && goals.categoryLimits.isEmpty) {
  return _legacyEvaluateRules(transactions); // your existing Phase 2 method, renamed
}
```
---
M7: Update MultiProvider in `main.dart`
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(
      create: (context) => GoalsProvider(
        GoalsRepository(context.read<DatabaseHelper>().database),
      ),
    ),
    ChangeNotifierProvider(
      create: (context) => ClassificationProvider(
        ClassificationRepository(context.read<DatabaseHelper>().database),
        ClassificationDetector(),
      ),
    ),
    ChangeNotifierProxyProvider2<GoalsProvider, ClassificationProvider, InsightsProvider>(
      create: (_) => InsightsProvider(insightsService, UserGoals.empty()),
      update: (_, goals, classifications, previous) =>
          previous!..onContextUpdated(goals.currentGoals, classifications),
    ),
  ],
  child: const MyApp(),
)
```
Call `classificationProvider.init(transactions)` once after loading transaction history (e.g. in `AppState.init()` or the first `build` of the home screen).
---
M8: UI Components
8a. Confirmation Card in Insights Screen
Show this card only when `classificationProvider.hasPendingConfirmations == true`.
Place it at the top of the Insights screen, above insight cards.
```dart
Consumer<ClassificationProvider>(
  builder: (context, cp, _) {
    if (!cp.hasPendingConfirmations) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('We found some recurring payments',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height(8)),
            const Text('Confirm to get more accurate insights.'),
            const SizedBox(height: 12),
            // List of pending items with toggle chips
            Wrap(
              spacing: 8,
              children: cp.pendingConfirmation.map((c) =>
                FilterChip(
                  label: Text(c.merchantOrCategory),
                  selected: true, // pre-selected by default
                  onSelected: (_) { /* toggle selection state */ },
                )
              ).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => cp.confirmDetected(cp.pendingConfirmation),
                  child: const Text('Confirm'),
                ),
                TextButton(
                  onPressed: () => cp.dismissPendingConfirmation(),
                  child: const Text('Skip'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  },
)
```
8b. Transaction Detail Screen — Classification Chips
Add this row at the bottom of the existing transaction detail screen:
```dart
Consumer<ClassificationProvider>(
  builder: (context, cp, _) {
    final current = cp.natureOf(transaction.category);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Expense type', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 8),
        Row(
          children: [
            ChoiceChip(
              label: const Text('Recurring payment'),
              selected: current == ExpenseNature.recurring,
              onSelected: (_) => cp.setClassification(
                transaction.category,
                ExpenseNature.recurring,
              ),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Sometime expense'),
              selected: current == ExpenseNature.sometime,
              onSelected: (_) => cp.setClassification(
                transaction.category,
                ExpenseNature.sometime,
              ),
            ),
          ],
        ),
      ],
    );
  },
)
```
Changing the chip updates the DB and triggers InsightsProvider to recalculate via the ProxyProvider.
8c. Goals Settings Screen
```dart
class GoalsSettingsScreen extends StatefulWidget { ... }

class _GoalsSettingsScreenState extends State<GoalsSettingsScreen> {
  late TextEditingController _monthlyController;
  // One controller per category

  @override
  void initState() {
    super.initState();
    final goals = context.read<GoalsProvider>().currentGoals;
    _monthlyController = TextEditingController(
      text: goals.monthlyTotalLimit > 0
          ? goals.monthlyTotalLimit.toStringAsFixed(0)
          : '',
    );
  }

  Future<void> _save() async {
    final goalsProvider = context.read<GoalsProvider>();
    final monthly = double.tryParse(_monthlyController.text) ?? 0;
    await goalsProvider.updateMonthlyLimit(monthly);
    // save per-category limits similarly
    if (mounted) Navigator.pop(context);
    // InsightsProvider recalculates automatically via ProxyProvider
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spending goals')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Section 1: Monthly total
            TextFormField(
              controller: _monthlyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Monthly total limit (₹)'),
            ),
            const SizedBox(height: 24),
            // Section 2: Per-category limits (one TextFormField per category)
            // ...
            const Spacer(),
            ElevatedButton(
              onPressed: _save,
              child: const Text('Save goals'),
            ),
          ],
        ),
      ),
    );
  }
}
```
---
Build Order
M1 — run migration, verify all 3 new tables exist in DB inspector
M2 — create models and repositories, unit test `getGoals()`, `save()`, `getAll()`
M3 — write `ClassificationDetector`, unit test with mock transaction history
M4 — wire `ClassificationProvider`, call `init()` on app load, verify `hasPendingConfirmations` works
M5 — wire `GoalsProvider`
M7 — update `MultiProvider`, add `debugPrint` in `InsightsProvider.onContextUpdated` to confirm chain fires
M6 — refactor engine rules, verify Phase 2 fallback still works when goals are empty
M8 — build all 3 UI components
End-to-end test: mark rent as recurring → confirm burn rate ignores it → raise monthly limit → confirm warning disappears instantly
---
Files to Create
`lib/models/user_goals.dart`
`lib/models/expense_classification.dart`
`lib/repositories/goals_repository.dart`
`lib/repositories/classification_repository.dart`
`lib/services/classification_detector.dart`
`lib/providers/goals_provider.dart`
`lib/providers/classification_provider.dart`
`lib/screens/goals_settings_screen.dart`
Files to Modify
`lib/database/database_helper.dart` — bump version, add `onUpgrade` with 3 new tables
`lib/providers/insights_provider.dart` — add `onContextUpdated(UserGoals, ClassificationProvider)`
`lib/services/insights_rule_engine.dart` — new signature, 4 rules, fallback to Phase 2
`lib/screens/insights_screen.dart` — add confirmation card at top
`lib/screens/transaction_detail_screen.dart` — add classification chips
`main.dart` — update `MultiProvider` to `ChangeNotifierProxyProvider2`