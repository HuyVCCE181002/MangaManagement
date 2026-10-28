// UC-43: KPI nạp/mở khóa từ SQLite. Catalog hybrid: API C# khi bật, SQLite khi tắt.
import '../models/admin_stats.dart';
import '../models/user.dart';
import 'auth_service.dart';
import 'backend_api_service.dart';
import 'database_helper.dart';

class AdminStatsService {
  AdminStatsService._();
  static final AdminStatsService instance = AdminStatsService._();

  /// Nạp thống kê dashboard. Chỉ admin được gọi.
  Future<AdminDashboardStats> load({DateTime? since, DateTime? until}) async {
    _requireAdmin();
    final local = await DatabaseHelper.instance.getAdminDashboardStats(
      since: since,
      until: until,
    );
    try {
      final catalog = await BackendApiService.instance.getCatalogStats();
      if (catalog == null) return local;
      return local.mergeCatalog(
        totalMangas: catalog.totalMangas,
        hiddenMangas: catalog.hiddenMangas,
        totalChapters: catalog.totalChapters,
        lockedChapters: catalog.lockedChapters,
        totalGenres: catalog.totalGenres,
        catalogSource: catalog.source,
      );
    } catch (_) {
      return local;
    }
  }

  void _requireAdmin() {
    if (AuthService.instance.currentUser.role != UserRole.admin) {
      throw StateError('Chỉ quản trị viên mới xem được dashboard.');
    }
  }
}
