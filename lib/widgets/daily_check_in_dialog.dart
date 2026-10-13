import 'package:flutter/material.dart';
import '../models/daily_check_in.dart';
import '../services/auth_service.dart';
import '../services/daily_check_in_service.dart';

/// Hộp thoại Điểm danh hàng ngày nhận điểm coins
class DailyCheckInDialog extends StatefulWidget {
  const DailyCheckInDialog({super.key});

  /// Hàm tiện ích mở Dialog
  static Future<void> show(BuildContext context) async {
    final user = AuthService.instance.currentUser;
    if (user.isGuest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để điểm danh nhận coins thưởng!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Đảm bảo dữ liệu mới nhất được nạp
    await DailyCheckInService.instance.loadForUser(user.id);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const DailyCheckInDialog(),
    );
  }

  @override
  State<DailyCheckInDialog> createState() => _DailyCheckInDialogState();
}

class _DailyCheckInDialogState extends State<DailyCheckInDialog> {
  bool _isSubmitting = false;

  Future<void> _handleCheckIn() async {
    final user = AuthService.instance.currentUser;
    if (user.isGuest) return;

    setState(() => _isSubmitting = true);

    final result = await DailyCheckInService.instance.checkIn(user.id);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.success) {
      _showRewardCongratulation(result.rewardCoins, result.streakDay);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showRewardCongratulation(int coins, int streakDay) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E212D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB800), Color(0xFFFF8A00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFB800).withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.card_giftcard_rounded,
                size: 52,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'ĐIỂM DANH THÀNH CÔNG!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Chuỗi liên tiếp: 🔥 $streakDay ngày',
              style: const TextStyle(
                color: Color(0xFFFFB800),
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2B2D3C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.monetization_on_rounded,
                    color: Color(0xFFFFB800),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '+$coins Coins',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Coins đã được cộng ngay vào ví của bạn!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFA0A5B5), fontSize: 13),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tuyệt Vời', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: DailyCheckInService.instance,
      builder: (context, _) {
        final service = DailyCheckInService.instance;
        final hasCheckedToday = service.hasCheckedInToday;
        final currentStreak = service.currentStreak;
        final totalCheckIns = service.totalCheckIns;
        final totalRewards = service.totalRewardCoins;
        final targetDay = service.nextTargetStreakDay;

        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141724) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Thanh kéo handle
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Header bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.event_available_rounded,
                                color: Color(0xFF6C5CE7),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Điểm Danh Nhận Quà',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Đóng',
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 16),

                  // Content scrollable
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      children: [
                        // Card Thống kê Streak & Quà
                        _buildStatsHeader(
                          currentStreak: currentStreak,
                          totalCheckIns: totalCheckIns,
                          totalRewards: totalRewards,
                          hasCheckedToday: hasCheckedToday,
                        ),
                        const SizedBox(height: 20),

                        // Tiêu đề bảng mốc thưởng
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Lộ trình nhận thưởng 7 ngày',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              hasCheckedToday ? 'Hôm nay: Đã nhận ✓' : 'Hôm nay: Chưa nhận',
                              style: TextStyle(
                                fontSize: 12,
                                color: hasCheckedToday ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Grid 7 ngày
                        _buildSevenDaysGrid(
                          hasCheckedToday: hasCheckedToday,
                          currentStreak: currentStreak,
                          targetDay: targetDay,
                        ),
                        const SizedBox(height: 24),

                        // Nút hành động chính
                        _buildCheckInButton(hasCheckedToday: hasCheckedToday),
                        const SizedBox(height: 20),

                        // Section Lịch sử điểm danh
                        _buildHistorySection(service.history),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Banner thống kê chuỗi streak
  Widget _buildStatsHeader({
    required int currentStreak,
    required int totalCheckIns,
    required int totalRewards,
    required bool hasCheckedToday,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFF4834D4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Text('🔥', style: TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentStreak > 0
                          ? 'Chuỗi: $currentStreak ngày liên tiếp!'
                          : 'Bắt đầu chuỗi điểm danh!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasCheckedToday
                          ? 'Bạn đã điểm danh hôm nay. Tiếp tục vào ngày mai nhé!'
                          : 'Điểm danh ngay hôm nay để không bị gián đoạn chuỗi.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniStat('Tổng điểm danh', '$totalCheckIns ngày'),
                Container(
                  width: 1,
                  height: 24,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                _buildMiniStat('Tổng coins nhận', '+$totalRewards'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String title, String value) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  /// Lưới 7 ngày điểm danh
  Widget _buildSevenDaysGrid({
    required bool hasCheckedToday,
    required int currentStreak,
    required int targetDay,
  }) {
    // 6 ngày đầu xếp thành lưới 3x2, ngày thứ 7 dạng banner đặc biệt
    final regularDays = kWeeklyCheckInRewards.take(6).toList();
    final vipDay = kWeeklyCheckInRewards.last;

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.95,
          ),
          itemCount: regularDays.length,
          itemBuilder: (context, index) {
            final config = regularDays[index];
            return _buildDayCard(
              config: config,
              hasCheckedToday: hasCheckedToday,
              currentStreak: currentStreak,
              targetDay: targetDay,
            );
          },
        ),
        const SizedBox(height: 10),
        _buildVipDayCard(
          config: vipDay,
          hasCheckedToday: hasCheckedToday,
          currentStreak: currentStreak,
          targetDay: targetDay,
        ),
      ],
    );
  }

  Widget _buildDayCard({
    required CheckInRewardConfig config,
    required bool hasCheckedToday,
    required int currentStreak,
    required int targetDay,
  }) {
    // Trạng thái ngày này:
    // Đã nhận: nếu config.day < targetDay hoặc (config.day == targetDay && hasCheckedToday)
    // Hôm nay cần nhận: config.day == targetDay && !hasCheckedToday
    // Sắp tới: config.day > targetDay
    final isClaimed = hasCheckedToday
        ? config.day <= targetDay
        : config.day < targetDay;
    final isToday = config.day == targetDay && !hasCheckedToday;

    return Container(
      decoration: BoxDecoration(
        color: isToday
            ? const Color(0xFFFFB800).withValues(alpha: 0.12)
            : isClaimed
                ? Colors.green.withValues(alpha: 0.08)
                : const Color(0xFF222634).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isToday
              ? const Color(0xFFFFB800)
              : isClaimed
                  ? Colors.green.withValues(alpha: 0.4)
                  : Colors.grey.withValues(alpha: 0.15),
          width: isToday ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            config.title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
              color: isToday
                  ? const Color(0xFFFFB800)
                  : isClaimed
                      ? Colors.green
                      : Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Icon(
            isClaimed
                ? Icons.check_circle_rounded
                : Icons.monetization_on_rounded,
            color: isClaimed
                ? Colors.green
                : isToday
                    ? const Color(0xFFFFB800)
                    : const Color(0xFFFFB800).withValues(alpha: 0.6),
            size: 28,
          ),
          const SizedBox(height: 6),
          Text(
            '+${config.coins}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isToday ? const Color(0xFFFFB800) : Colors.white70,
            ),
          ),
          if (isClaimed) ...[
            const SizedBox(height: 2),
            const Text(
              'Đã nhận',
              style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVipDayCard({
    required CheckInRewardConfig config,
    required bool hasCheckedToday,
    required int currentStreak,
    required int targetDay,
  }) {
    final isClaimed = hasCheckedToday
        ? config.day <= targetDay
        : config.day < targetDay;
    final isToday = config.day == targetDay && !hasCheckedToday;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isToday
              ? [const Color(0xFFFFB800), const Color(0xFFFF8A00)]
              : isClaimed
                  ? [Colors.green.shade800, Colors.green.shade900]
                  : [const Color(0xFF2C2250), const Color(0xFF1E1838)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday ? Colors.amberAccent : Colors.amber.withValues(alpha: 0.3),
          width: isToday ? 2 : 1,
        ),
        boxShadow: isToday
            ? [
                BoxShadow(
                  color: const Color(0xFFFFB800).withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isClaimed ? Icons.check_circle_rounded : Icons.card_giftcard_rounded,
              color: isClaimed ? Colors.white : const Color(0xFFFFEAA7),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Ngày 7: Hộp Quà VIP',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'VIP',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isClaimed
                      ? 'Đã nhận phần thưởng VIP cao nhất!'
                      : 'Hoàn thành chuỗi 7 ngày để nhận quà lớn nhất!',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '+${config.coins} Coins',
              style: const TextStyle(
                color: Color(0xFFFFEAA7),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Nút bấm điểm danh
  Widget _buildCheckInButton({required bool hasCheckedToday}) {
    if (hasCheckedToday) {
      return Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
              SizedBox(width: 8),
              Text(
                'Đã Điểm Danh Hôm Nay (Hẹn mai nhé!)',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final nextCoins = DailyCheckInService.instance.nextRewardConfig.coins;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C5CE7),
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          shadowColor: const Color(0xFF6C5CE7).withValues(alpha: 0.5),
        ),
        onPressed: _isSubmitting ? null : _handleCheckIn,
        child: _isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.touch_app_rounded, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Điểm Danh Ngay (+$nextCoins Coins)',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Danh sách lịch sử điểm danh gần nhất
  Widget _buildHistorySection(List<DailyCheckInHistoryItem> history) {
    if (history.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lịch sử nhận thưởng gần đây',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E212D).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: history.length > 5 ? 5 : history.length,
            separatorBuilder: (ctx, i) => Divider(
              height: 1,
              color: Colors.white.withValues(alpha: 0.05),
            ),
            itemBuilder: (ctx, index) {
              final item = history[index];
              return ListTile(
                dense: true,
                visualDensity: const VisualDensity(vertical: -2),
                leading: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.monetization_on_rounded,
                    color: Color(0xFFFFB800),
                    size: 18,
                  ),
                ),
                title: Text(
                  'Điểm danh Ngày ${item.streakDay}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  item.checkInDate,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                trailing: Text(
                  '+${item.rewardCoins} coins',
                  style: const TextStyle(
                    color: Color(0xFFFFB800),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
