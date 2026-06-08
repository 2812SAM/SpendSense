import 'package:flutter/material.dart';

class TransactionRow extends StatelessWidget {
  final String category;
  final String emoji;
  final String timestamp;
  final double amount;
  final bool isSynced;
  final VoidCallback? onTap;

  const TransactionRow({
    super.key,
    required this.category,
    required this.emoji,
    required this.timestamp,
    required this.amount,
    required this.isSynced,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final amountStr = amount.toStringAsFixed(0);
    // Enhancement #2: Scale font if amount exceeds 7 digits
    final amountFontSize = amountStr.length > 7 ? 14.0 * 0.85 : 14.0;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1),
          ),
        ),
        child: Row(
          children: [
            // Sync indicator bar
            Container(
              width: 3,
              height: 36,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSynced
                    ? const Color(0xFF10B981)
                    : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Category icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 12),
            // Category & timestamp
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timestamp.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            // Amount with explicit cloud icon
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSynced)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.cloud_done_rounded,
                      size: 14,
                      color: Color(0xFF10B981),
                    ),
                  ),
                Text(
                  '₹$amountStr',
                  style: TextStyle(
                    fontSize: amountFontSize,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: const Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
