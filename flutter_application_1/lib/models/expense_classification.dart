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

  @override
  String toString() {
    return 'ExpenseClassification(id: $merchantOrCategory, nature: ${nature.name}, expected: $expectedAmount, confirmed: $userConfirmed)';
  }
}
