import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class MangaStatusBadge extends StatelessWidget {
  final String status;
  final bool compact;

  const MangaStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    String displayLabel;

    switch (status.toLowerCase()) {
      case 'completed':
        badgeColor = AppColors.statusCompleted;
        displayLabel = 'Hoàn thành';
        break;
      case 'hiatus':
        badgeColor = AppColors.statusHiatus;
        displayLabel = 'Tạm ngưng';
        break;
      case 'ongoing':
      default:
        badgeColor = AppColors.statusOngoing;
        displayLabel = 'Đang ra';
        break;
    }

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: badgeColor.withValues(alpha: 0.5), width: 0.8),
        ),
        child: Text(
          displayLabel,
          style: TextStyle(
            color: badgeColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withValues(alpha: 0.6), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            displayLabel,
            style: TextStyle(
              color: badgeColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
