import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/daily_check_in.dart';
import 'database_helper.dart';
import 'wallet_service.dart';

/// Service quản lý nghiệp vụ Điểm danh hàng ngày (Daily Check-in)
class DailyCheckInService extends ChangeNotifier {
  static final DailyCheckInService instance = DailyCheckInService._internal();
  DailyCheckInService._internal();

  UserCheckInStats? _stats;
  List<DailyCheckInHistoryItem> _history = [];
  bool _isLoading = false;
  String? _lastLoadedUserId;

  UserCheckInStats? get stats => _stats;
  List<DailyCheckInHistoryItem> get history => List.unmodifiable(_history);
  bool get isLoading => _isLoading;

  /// Format ngày yyyy-MM-dd
  static String formatDate(DateTime dt) {
    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Chuỗi ngày hôm nay
  String get todayDateStr => formatDate(DateTime.now());

  /// Chuỗi ngày hôm qua
  String get yesterdayDateStr =>
      formatDate(DateTime.now().subtract(const Duration(days: 1)));

  /// Đã điểm danh hôm nay chưa?
  bool get hasCheckedInToday => _stats?.lastCheckInDate == todayDateStr;

  /// Chuỗi streak hiện tại (1 - 7)
  int get currentStreak => _stats?.currentStreak ?? 0;

  /// Tổng số lượt đã điểm danh
  int get totalCheckIns => _stats?.totalCheckIns ?? 0;

  /// Tổng số coins đã nhận từ điểm danh
  int get totalRewardCoins => _stats?.totalRewardCoins ?? 0;

  /// Mốc ngày nhận thưởng tiếp theo (1 - 7)
  int get nextTargetStreakDay {
    if (_stats == null || _stats!.lastCheckInDate.isEmpty) {
      return 1;
    }
    if (hasCheckedInToday) {
      // Đã nhận hôm nay, mốc hôm nay là currentStreak
      return ((currentStreak - 1) % 7) + 1;
    }
    if (_stats!.lastCheckInDate == yesterdayDateStr) {
      // Hôm qua có điểm danh -> ngày tiếp theo
      return (currentStreak % 7) + 1;
    }
    // Bị đứt chuỗi
    return 1;
  }

  /// Config phần thưởng cho lượt điểm danh kế tiếp (hoặc hôm nay nếu chưa nhận)
  CheckInRewardConfig get nextRewardConfig {
    final targetDay = nextTargetStreakDay;
    return kWeeklyCheckInRewards.firstWhere(
      (c) => c.day == targetDay,
      orElse: () => kWeeklyCheckInRewards.first,
    );
  }

  /// Tải thông tin điểm danh và lịch sử của người dùng
  Future<void> loadForUser(String userId, {bool force = false}) async {
    if (userId.isEmpty) {
      clearCache();
      return;
    }

    // Nếu đang tải hoặc đã tải user này rồi và không yêu cầu force -> bỏ qua
    if (_isLoading) return;
    if (!force && _lastLoadedUserId == userId && _stats != null) return;

    _isLoading = true;
    _lastLoadedUserId = userId;

    try {
      final db = DatabaseHelper.instance;
      var stats = await db.getUserCheckInStats(userId);
      if (stats == null) {
        stats = UserCheckInStats.empty(userId);
        await db.saveUserCheckInStats(stats);
      }
      _stats = stats;
      _history = await db.getCheckInHistory(userId, limit: 14);
    } catch (e) {
      debugPrint('[DailyCheckInService] loadForUser error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Thực hiện điểm danh nhận quà
  Future<({bool success, String message, int rewardCoins, int streakDay})> checkIn(
    String userId,
  ) async {
    if (userId.isEmpty) {
      return (
        success: false,
        message: 'Bạn cần đăng nhập để điểm danh nhận coins!',
        rewardCoins: 0,
        streakDay: 0,
      );
    }

    final db = DatabaseHelper.instance;

    // Đảm bảo dữ liệu đã được tải
    if (_stats == null || _lastLoadedUserId != userId) {
      await loadForUser(userId);
    }

    final today = todayDateStr;
    final yesterday = yesterdayDateStr;

    // 1. Kiểm tra nếu hôm nay đã điểm danh rồi
    if (_stats != null && _stats!.lastCheckInDate == today) {
      final currentDay = ((_stats!.currentStreak - 1) % 7) + 1;
      return (
        success: false,
        message: 'Hôm nay bạn đã nhận quà điểm danh rồi! Hãy quay lại vào ngày mai nhé.',
        rewardCoins: 0,
        streakDay: currentDay,
      );
    }

    // 2. Tính toán streak mới
    int newStreak;
    if (_stats == null || _stats!.lastCheckInDate.isEmpty) {
      newStreak = 1;
    } else if (_stats!.lastCheckInDate == yesterday) {
      // Tiếp nối chuỗi liên tục
      newStreak = (_stats!.currentStreak % 7) + 1;
    } else {
      // Bị gián đoạn ngày -> reset chuỗi về 1
      newStreak = 1;
    }

    // 3. Tìm phần thưởng tương ứng
    final rewardConfig = kWeeklyCheckInRewards.firstWhere(
      (c) => c.day == newStreak,
      orElse: () => kWeeklyCheckInRewards.first,
    );
    final coins = rewardConfig.coins;

    try {
      // 4. Cộng coins vào ví và ghi giao dịch bonus
      final rewardResult = await WalletService.instance.rewardCoins(
        userId: userId,
        amount: coins,
        description: 'Điểm danh ngày $newStreak: +$coins coins',
      );

      if (!rewardResult.success) {
        return (
          success: false,
          message: 'Không thể cộng coins vào ví: ${rewardResult.message}',
          rewardCoins: 0,
          streakDay: 0,
        );
      }

      // 5. Ghi lịch sử điểm danh
      final historyItem = DailyCheckInHistoryItem(
        id: const Uuid().v4(),
        userId: userId,
        checkInDate: today,
        streakDay: newStreak,
        rewardCoins: coins,
        createdAt: DateTime.now(),
      );
      await db.insertCheckInHistory(historyItem);

      // 6. Cập nhật thống kê người dùng
      final currentTotalCheckIns = _stats?.totalCheckIns ?? 0;
      final currentTotalRewards = _stats?.totalRewardCoins ?? 0;

      final updatedStats = UserCheckInStats(
        userId: userId,
        lastCheckInDate: today,
        currentStreak: newStreak,
        totalCheckIns: currentTotalCheckIns + 1,
        totalRewardCoins: currentTotalRewards + coins,
        updatedAt: DateTime.now(),
      );
      await db.saveUserCheckInStats(updatedStats);

      // 7. Cập nhật state in-memory
      _stats = updatedStats;
      _history.insert(0, historyItem);
      notifyListeners();

      final bonusText = rewardConfig.isSpecial ? ' 🎁 Phần quà VIP đặc biệt!' : '';
      return (
        success: true,
        message: 'Điểm danh ngày $newStreak thành công! Bạn nhận được +$coins coins.$bonusText',
        rewardCoins: coins,
        streakDay: newStreak,
      );
    } catch (e) {
      debugPrint('[DailyCheckInService] checkIn error: $e');
      return (
        success: false,
        message: 'Có lỗi xảy ra khi điểm danh: $e',
        rewardCoins: 0,
        streakDay: 0,
      );
    }
  }

  /// Reset cache khi đăng xuất
  void clearCache() {
    _stats = null;
    _history = [];
    _lastLoadedUserId = null;
    _isLoading = false;
    notifyListeners();
  }
}
