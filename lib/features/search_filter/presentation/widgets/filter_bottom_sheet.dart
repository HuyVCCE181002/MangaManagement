import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:manga_management_app/features/manga/domain/entities/manga_filter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../providers/search_filter_provider.dart';

class FilterBottomSheet extends StatelessWidget {
  const FilterBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SearchFilterProvider>(
      builder: (context, filterProvider, child) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title and Reset button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Bộ Lọc & Sắp Xếp',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (filterProvider.hasActiveFilter)
                    TextButton(
                      onPressed: () => filterProvider.resetFilters(),
                      child: const Text('Đặt lại', style: TextStyle(color: AppColors.secondary)),
                    ),
                ],
              ),
              const Divider(color: AppColors.surfaceBorder, height: 24),

              Expanded(
                child: ListView(
                  children: [
                    // Sắp xếp (Sorting)
                    const Text(
                      'Sắp xếp theo',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildSortChip(
                          context,
                          filterProvider,
                          MangaSortBy.ratingDesc,
                          'Đánh giá cao nhất',
                        ),
                        _buildSortChip(
                          context,
                          filterProvider,
                          MangaSortBy.updatedDesc,
                          'Mới cập nhật',
                        ),
                        _buildSortChip(
                          context,
                          filterProvider,
                          MangaSortBy.titleAsc,
                          'Tên A-Z',
                        ),
                        _buildSortChip(
                          context,
                          filterProvider,
                          MangaSortBy.chaptersDesc,
                          'Số chapter nhiều nhất',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Trạng thái phát hành
                    const Text(
                      'Trạng thái phát hành',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildStatusChip(context, filterProvider, null, 'Tất cả'),
                        ...AppConstants.mangaStatuses.map(
                          (st) => _buildStatusChip(
                            context,
                            filterProvider,
                            st,
                            st == 'Ongoing'
                                ? 'Đang ra'
                                : st == 'Completed'
                                    ? 'Hoàn thành'
                                    : 'Tạm ngưng',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Điểm đánh giá tối thiểu (Rating Slider)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Điểm đánh giá tối thiểu',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          filterProvider.minRating > 0
                              ? 'Từ ${filterProvider.minRating.toStringAsFixed(1)} ★'
                              : 'Bất kỳ',
                          style: const TextStyle(
                            color: AppColors.star,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: filterProvider.minRating,
                      min: 0.0,
                      max: 9.5,
                      divisions: 19,
                      activeColor: AppColors.primary,
                      inactiveColor: AppColors.surfaceVariant,
                      onChanged: (val) => filterProvider.setMinRating(val),
                    ),
                    const SizedBox(height: 16),

                    // Thể loại (Genre chips)
                    const Text(
                      'Thể loại truyện',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AppConstants.availableGenres.map((genre) {
                        final isSelected = filterProvider.selectedGenres.contains(genre);
                        return FilterChip(
                          label: Text(genre),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.surfaceVariant,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                          onSelected: (_) => filterProvider.toggleGenre(genre),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Áp Dụng Bộ Lọc'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortChip(
    BuildContext context,
    SearchFilterProvider provider,
    MangaSortBy sortBy,
    String label,
  ) {
    final isSelected = provider.sortBy == sortBy;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceVariant,
      labelStyle: TextStyle(
        fontSize: 12,
        color: isSelected ? Colors.white : AppColors.textSecondary,
      ),
      onSelected: (val) {
        if (val) provider.setSortBy(sortBy);
      },
    );
  }

  Widget _buildStatusChip(
    BuildContext context,
    SearchFilterProvider provider,
    String? status,
    String label,
  ) {
    final isSelected = provider.selectedStatus == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceVariant,
      labelStyle: TextStyle(
        fontSize: 12,
        color: isSelected ? Colors.white : AppColors.textSecondary,
      ),
      onSelected: (val) {
        if (val) provider.setStatus(status);
      },
    );
  }
}
