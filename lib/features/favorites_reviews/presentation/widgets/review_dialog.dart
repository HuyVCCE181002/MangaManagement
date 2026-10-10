import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/review.dart';

class ReviewDialog extends StatefulWidget {
  final String mangaId;
  final Review? initialReview;
  final Function(Review review) onSave;
  final VoidCallback? onDelete;

  const ReviewDialog({
    super.key,
    required this.mangaId,
    this.initialReview,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  late double _selectedScore;
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _selectedScore = widget.initialReview?.score ?? 5.0;
    _noteController = TextEditingController(text: widget.initialReview?.note ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.surfaceBorder, width: 1),
      ),
      title: Row(
        children: [
          const Icon(Icons.rate_review_rounded, color: AppColors.primaryLight, size: 22),
          const SizedBox(width: 8),
          Text(
            widget.initialReview != null ? 'Sửa Đánh Giá & Ghi Chú' : 'Đánh Giá & Ghi Chú',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chấm điểm trải nghiệm đọc của bạn:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            // Star Selector (1 to 5 stars)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starValue = (index + 1).toDouble();
                final isFilled = starValue <= _selectedScore;
                return IconButton(
                  icon: Icon(
                    isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: AppColors.star,
                    size: 32,
                  ),
                  onPressed: () {
                    setState(() => _selectedScore = starValue);
                  },
                );
              }),
            ),
            Center(
              child: Text(
                '$_selectedScore / 5.0 Sao',
                style: const TextStyle(
                  color: AppColors.star,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ghi chú cá nhân (Cảm nhận, đoạn tâm đắc...):',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Ví dụ: Arc giải cứu Ace đỉnh cao, nét vẽ càng ngày càng chi tiết...',
                fillColor: AppColors.surfaceVariant,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.initialReview != null && widget.onDelete != null)
          TextButton(
            onPressed: () {
              widget.onDelete!();
              Navigator.pop(context);
            },
            child: const Text('Xóa', style: TextStyle(color: AppColors.error)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy', style: TextStyle(color: AppColors.textMuted)),
        ),
        ElevatedButton(
          onPressed: () {
            final review = Review(
              id: widget.initialReview?.id ?? const Uuid().v4(),
              mangaId: widget.mangaId,
              score: _selectedScore,
              note: _noteController.text.trim(),
              createdAt: DateTime.now(),
            );
            widget.onSave(review);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(80, 40),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
