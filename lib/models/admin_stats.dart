import 'coin_transaction.dart';

/// Điểm dữ liệu theo ngày (doanh thu VND, xu, số lượng).
class DailyPoint {
  final String day;
  final int revenueVnd;
  final int coins;
  final int count;
  const DailyPoint({
    required this.day,
    this.revenueVnd = 0,
    this.coins = 0,
    this.count = 0,
  });
}

/// Top chapter được mở khóa nhiều nhất (từ giao dịch purchase completed).
class TopUnlockedChapter {
  final String chapterId;
  final String chapterTitle;
  final int chapterNumber;
  final String mangaId;
  final String mangaTitle;
  final int unlocks;
  final int coinsSpent;
  const TopUnlockedChapter({
    required this.chapterId,
    required this.chapterTitle,
    required this.chapterNumber,
    required this.mangaId,
    required this.mangaTitle,
    required this.unlocks,
    required this.coinsSpent,
  });
}

/// Cảnh báo tính từ SQLite. Mỗi cảnh báo có điều kiện rõ ràng và deep-link.
class DashboardAlert {
  final String id;
  final String title;
  final String detail;
  final String target;
  const DashboardAlert({
    required this.id,
    required this.title,
    required this.detail,
    required this.target,
  });
}

/// Số liệu tổng hợp cho dashboard quản trị (UC-43).
/// Catalog (manga/chapter/genre) ưu tiên API C# khi bật, SQLite khi tắt.
///
/// Định nghĩa KPI:
/// - totalUsers: COUNT users. activeUsers/deactivatedUsers theo is_active.
/// - admin/staff/reader: COUNT theo role và active.
/// - totalMangas: COUNT mangas. hiddenMangas theo is_hidden.
/// - totalChapters/lockedChapters/totalGenres: COUNT chapters/genres.
/// - revenueVnd: SUM(payment_amount) chỉ với type=deposit AND status=completed.
/// - coinsCredited: SUM(amount) chỉ deposit completed.
/// - completed/failed/pendingDeposits: COUNT deposit theo status
///   (failed gộp failed+cancelled).
/// - unlockCount/coinsSpentOnUnlocks: COUNT/SUM(ABS(amount)) với
///   type=purchase AND status=completed.
/// - Không coi số giao dịch là số người dùng; không coi xu là VND.
class AdminDashboardStats {
  final int totalUsers;
  final int activeUsers;
  final int deactivatedUsers;
  final int adminCount;
  final int staffCount;
  final int readerCount;
  final int totalMangas;
  final int hiddenMangas;
  final int totalChapters;
  final int lockedChapters;
  final int totalGenres;
  final int walletBalance;
  final int totalEarned;
  final int totalSpent;
  final int completedDeposits;
  final int failedDeposits;
  final int pendingDeposits;
  final int coinsCredited;
  final int revenueVnd;
  final int unlockCount;
  final int coinsSpentOnUnlocks;
  final List<CoinTransaction> recentTransactions;
  final Map<String, int> transactionsByStatus;
  final Map<String, int> usersByRole;
  final Map<String, int> mangasByGenre;
  final List<DailyPoint> revenueByDay;
  final List<DailyPoint> unlockSpendByDay;
  final List<TopUnlockedChapter> topUnlockedChapters;
  final List<DashboardAlert> alerts;
  final int pendingStaleCount;
  final int inactivePackageCount;
  final int invalidPremiumCount;
  final int previousRevenueVnd;
  final int previousFailedDeposits;
  final String catalogSource;

  const AdminDashboardStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.deactivatedUsers,
    required this.adminCount,
    required this.staffCount,
    required this.readerCount,
    required this.totalMangas,
    required this.hiddenMangas,
    required this.totalChapters,
    required this.lockedChapters,
    required this.totalGenres,
    required this.walletBalance,
    required this.totalEarned,
    required this.totalSpent,
    required this.completedDeposits,
    required this.failedDeposits,
    required this.pendingDeposits,
    required this.coinsCredited,
    required this.revenueVnd,
    required this.unlockCount,
    required this.coinsSpentOnUnlocks,
    this.recentTransactions = const [],
    this.transactionsByStatus = const {},
    this.usersByRole = const {},
    this.mangasByGenre = const {},
    this.revenueByDay = const [],
    this.unlockSpendByDay = const [],
    this.topUnlockedChapters = const [],
    this.alerts = const [],
    this.pendingStaleCount = 0,
    this.inactivePackageCount = 0,
    this.invalidPremiumCount = 0,
    this.previousRevenueVnd = 0,
    this.previousFailedDeposits = 0,
    this.catalogSource = 'sqlite',
  });

  AdminDashboardStats mergeCatalog({
    required int totalMangas,
    required int hiddenMangas,
    required int totalChapters,
    required int lockedChapters,
    required int totalGenres,
    required String catalogSource,
  }) {
    return AdminDashboardStats(
      totalUsers: totalUsers,
      activeUsers: activeUsers,
      deactivatedUsers: deactivatedUsers,
      adminCount: adminCount,
      staffCount: staffCount,
      readerCount: readerCount,
      totalMangas: totalMangas,
      hiddenMangas: hiddenMangas,
      totalChapters: totalChapters,
      lockedChapters: lockedChapters,
      totalGenres: totalGenres,
      walletBalance: walletBalance,
      totalEarned: totalEarned,
      totalSpent: totalSpent,
      completedDeposits: completedDeposits,
      failedDeposits: failedDeposits,
      pendingDeposits: pendingDeposits,
      coinsCredited: coinsCredited,
      revenueVnd: revenueVnd,
      unlockCount: unlockCount,
      coinsSpentOnUnlocks: coinsSpentOnUnlocks,
      recentTransactions: recentTransactions,
      transactionsByStatus: transactionsByStatus,
      usersByRole: usersByRole,
      mangasByGenre: mangasByGenre,
      revenueByDay: revenueByDay,
      unlockSpendByDay: unlockSpendByDay,
      topUnlockedChapters: topUnlockedChapters,
      alerts: alerts,
      pendingStaleCount: pendingStaleCount,
      inactivePackageCount: inactivePackageCount,
      invalidPremiumCount: invalidPremiumCount,
      previousRevenueVnd: previousRevenueVnd,
      previousFailedDeposits: previousFailedDeposits,
      catalogSource: catalogSource,
    );
  }

  int get visibleMangas => totalMangas - hiddenMangas;

  double get averageRevenuePerDeposit =>
      completedDeposits == 0 ? 0 : revenueVnd / completedDeposits;

  /// Tỷ lệ thay đổi doanh thu so với kỳ trước. Null khi kỳ trước = 0.
  double? get revenueChangeRatio {
    if (previousRevenueVnd <= 0) return null;
    return (revenueVnd - previousRevenueVnd) / previousRevenueVnd;
  }
}
