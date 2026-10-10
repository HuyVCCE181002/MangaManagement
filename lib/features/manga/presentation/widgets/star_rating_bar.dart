import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';

class StarRatingBar extends StatelessWidget {
  final double rating; // Thang 10 hoặc 5
  final double starSize;
  final bool showScoreText;
  final TextStyle? textStyle;

  const StarRatingBar({
    super.key,
    required this.rating,
    this.starSize = 14,
    this.showScoreText = true,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.star_rounded,
          color: AppColors.star,
          size: starSize,
        ),
        const SizedBox(width: 4),
        if (showScoreText)
          Text(
            Formatters.rating(rating),
            style: textStyle ??
                const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
          ),
      ],
    );
  }
}
