import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/coin_package.dart';
import 'auth_service.dart';
import 'database_helper.dart';

/// Service quản lý gói coins (CRUD cho Admin)
class CoinPackageService extends ChangeNotifier {
  static final CoinPackageService instance = CoinPackageService._internal();
  CoinPackageService._internal();

  List<CoinPackage> _packages = [];
  List<CoinPackage> get packages => List.unmodifiable(_packages);

  /// Load tất cả gói coins (Admin)
  Future<void> loadAll() async {
    _packages = await DatabaseHelper.instance.getAllCoinPackages(
      activeOnly: false,
    );
    notifyListeners();
  }

  /// Lấy gói coins active (cho user)
  Future<List<CoinPackage>> getActivePackages() async {
    return await DatabaseHelper.instance.getAllCoinPackages(activeOnly: true);
  }

  bool get _isAdmin =>
      AuthService.instance.currentUser.role.canManageCoinPackages;

  /// Thêm gói coins mới
  Future<({bool success, String message, CoinPackage? package})> createPackage({
    required String name,
    required int coins,
    required double price,
    int bonusCoins = 0,
    bool isActive = true,
    bool isFeatured = false,
    int sortOrder = 0,
  }) async {
    // Validation
    if (name.trim().isEmpty) {
      return (
        success: false,
        message: 'Tên gói không được để trống.',
        package: null,
      );
    }
    if (coins <= 0) {
      return (
        success: false,
        message: 'Số coins phải lớn hơn 0.',
        package: null,
      );
    }
    if (price < 0) {
      return (
        success: false,
        message: 'Giá tiền không được âm.',
        package: null,
      );
    }
    if (bonusCoins < 0) {
      return (
        success: false,
        message: 'Bonus coins không được âm.',
        package: null,
      );
    }
    if (!_isAdmin) {
      return (
        success: false,
        message: 'Chỉ quản trị viên mới được tạo gói coins.',
        package: null,
      );
    }

    final newPkg = CoinPackage(
      id: 'pkg_${const Uuid().v4()}',
      name: name.trim(),
      coins: coins,
      price: price,
      bonusCoins: bonusCoins,
      isActive: isActive,
      isFeatured: isFeatured,
      sortOrder: sortOrder,
      createdAt: DateTime.now(),
    );

    await DatabaseHelper.instance.insertCoinPackage(newPkg);
    await loadAll();
    return (
      success: true,
      message: 'Đã tạo gói coins mới thành công!',
      package: newPkg,
    );
  }

  /// Cập nhật gói coins
  Future<({bool success, String message})> updatePackage(
    CoinPackage pkg,
  ) async {
    if (!_isAdmin) {
      return (
        success: false,
        message: 'Chỉ quản trị viên mới được cập nhật gói coins.',
      );
    }
    if (pkg.name.trim().isEmpty) {
      return (success: false, message: 'Tên gói không được để trống.');
    }
    if (pkg.coins <= 0) {
      return (success: false, message: 'Số coins phải lớn hơn 0.');
    }
    if (pkg.price < 0) {
      return (success: false, message: 'Giá tiền không được âm.');
    }

    await DatabaseHelper.instance.updateCoinPackage(pkg);
    await loadAll();
    return (success: true, message: 'Đã cập nhật gói coins thành công!');
  }

  /// Toggle trạng thái active
  Future<({bool success, String message})> toggleActive(String id) async {
    if (!_isAdmin) {
      return (
        success: false,
        message: 'Chỉ quản trị viên mới được đổi trạng thái gói coins.',
      );
    }
    final pkg = await DatabaseHelper.instance.getCoinPackageById(id);
    if (pkg == null) {
      return (success: false, message: 'Không tìm thấy gói coins.');
    }
    final updated = pkg.copyWith(isActive: !pkg.isActive);
    await DatabaseHelper.instance.updateCoinPackage(updated);
    await loadAll();
    return (
      success: true,
      message: updated.isActive
          ? 'Đã kích hoạt gói "${updated.name}".'
          : 'Đã tạm dừng gói "${updated.name}".',
    );
  }

  /// Toggle featured
  Future<({bool success, String message})> toggleFeatured(String id) async {
    if (!_isAdmin) {
      return (
        success: false,
        message: 'Chỉ quản trị viên mới được đánh dấu gói nổi bật.',
      );
    }
    final pkg = await DatabaseHelper.instance.getCoinPackageById(id);
    if (pkg == null) {
      return (success: false, message: 'Không tìm thấy gói coins.');
    }
    final updated = pkg.copyWith(isFeatured: !pkg.isFeatured);
    await DatabaseHelper.instance.updateCoinPackage(updated);
    await loadAll();
    return (
      success: true,
      message: updated.isFeatured
          ? 'Đã đánh dấu nổi bật.'
          : 'Đã bỏ đánh dấu nổi bật.',
    );
  }

  /// Xóa gói coins (UC-48): nếu gói đã có giao dịch lịch sử thì chỉ
  /// tạm dừng thay vì xóa hẳn, để các giao dịch cũ vẫn giữ snapshot.
  Future<({bool success, String message})> deletePackage(String id) async {
    if (!_isAdmin) {
      return (
        success: false,
        message: 'Chỉ quản trị viên mới được gỡ gói coins.',
      );
    }
    final pkg = await DatabaseHelper.instance.getCoinPackageById(id);
    if (pkg == null) {
      return (success: false, message: 'Không tìm thấy gói coins.');
    }
    final usedCount = await DatabaseHelper.instance.countTransactionsByPackage(
      id,
    );
    if (usedCount > 0) {
      final updated = pkg.copyWith(isActive: false);
      await DatabaseHelper.instance.updateCoinPackage(updated);
      await loadAll();
      return (
        success: true,
        message:
            'Gói "${pkg.name}" đã có $usedCount giao dịch nên chỉ được tạm dừng, lịch sử được giữ nguyên.',
      );
    }
    await DatabaseHelper.instance.deleteCoinPackage(id);
    await loadAll();
    return (success: true, message: 'Đã xóa gói "${pkg.name}" thành công.');
  }
}
