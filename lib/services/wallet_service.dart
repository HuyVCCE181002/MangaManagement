import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/wallet.dart';
import '../models/coin_transaction.dart';
import '../models/coin_package.dart';
import '../models/user.dart';
import 'payment_verification_service.dart';
import 'database_helper.dart';

/// Service quản lý ví coins & giao dịch
class WalletService extends ChangeNotifier {
  static final WalletService instance = WalletService._internal();
  WalletService._internal();

  Wallet? _currentWallet;
  List<CoinTransaction> _transactions = [];
  List<CoinPackage> _packages = [];

  Wallet? get currentWallet => _currentWallet;
  List<CoinTransaction> get transactions => List.unmodifiable(_transactions);
  List<CoinPackage> get packages => List.unmodifiable(_packages);

  int get balance => _currentWallet?.balance ?? 0;
  int get totalEarned => _currentWallet?.totalEarned ?? 0;
  int get totalSpent => _currentWallet?.totalSpent ?? 0;

  /// Load ví và giao dịch của user hiện tại
  Future<void> loadWallet(String userId) async {
    final db = DatabaseHelper.instance;

    // Lấy hoặc tạo ví
    var wallet = await db.getWalletByUserId(userId);
    if (wallet == null) {
      final now = DateTime.now();
      wallet = Wallet(
        id: 'wallet_$userId',
        userId: userId,
        balance: 0,
        totalEarned: 0,
        totalSpent: 0,
        createdAt: now,
        updatedAt: now,
      );
      await db.insertWallet(wallet);
    }
    _currentWallet = wallet;

    // Lấy lịch sử giao dịch
    _transactions = await db.getTransactionsByUserId(userId);

    // Lấy danh sách gói coins (chỉ gói active)
    _packages = await db.getAllCoinPackages(activeOnly: true);

    notifyListeners();
  }

  /// Lấy lịch sử giao dịch (refresh)
  Future<void> refreshTransactions() async {
    if (_currentWallet == null) return;
    _transactions = await DatabaseHelper.instance.getTransactionsByUserId(
      _currentWallet!.userId,
    );
    notifyListeners();
  }

  /// Fetches the authenticated receipt itself; UI cannot supply a completed
  /// status, coin amount or payment result for this operation.
  Future<CoinTransaction> syncServerPayment(
    AppUser user,
    String orderId,
  ) async {
    final order = await PaymentVerificationService.instance.getOrder(
      user,
      orderId,
    );
    final transaction = await DatabaseHelper.instance.cacheServerPayment(
      user.id,
      order,
    );
    await loadWallet(user.id);
    return transaction;
  }

  Future<void> recoverServerPayments(AppUser user) async {
    final orders = await PaymentVerificationService.instance.getOrders(user);
    for (final order in orders.where((order) => order.status == 'completed')) {
      await DatabaseHelper.instance.cacheServerPayment(user.id, order);
    }
    await loadWallet(user.id);
  }

  /// Tạo giao dịch nạp ở trạng thái chờ xác minh.
  /// Không thay đổi số dư cho đến khi cổng thanh toán/backend xác nhận.
  Future<({bool success, String message, CoinTransaction? transaction})>
  createPendingDeposit({
    required String userId,
    required CoinPackage package,
    required String paymentMethod,
    required String transferCode,
  }) async {
    final db = DatabaseHelper.instance;
    var wallet = await db.getWalletByUserId(userId);
    if (wallet == null) {
      final now = DateTime.now();
      wallet = Wallet(
        id: 'wallet_$userId',
        userId: userId,
        balance: 0,
        totalEarned: 0,
        totalSpent: 0,
        createdAt: now,
        updatedAt: now,
      );
      await db.insertWallet(wallet);
    }

    if (!package.isActive) {
      return (
        success: false,
        message: 'Gói coins này hiện không khả dụng.',
        transaction: null,
      );
    }

    final existingPending = (await db.getTransactionsByUserId(userId))
        .where(
          (tx) =>
              tx.type == TransactionType.deposit &&
              tx.status == TransactionStatus.pending &&
              tx.packageId == package.id &&
              tx.paymentMethod == paymentMethod,
        )
        .firstOrNull;
    if (existingPending != null) {
      return (
        success: true,
        message: 'Giao dịch này đang chờ xác minh.',
        transaction: existingPending,
      );
    }

    final tx = CoinTransaction(
      id: const Uuid().v4(),
      userId: userId,
      walletId: wallet.id,
      type: TransactionType.deposit,
      amount: package.totalCoins,
      coinsBefore: wallet.balance,
      coinsAfter: wallet.balance,
      description:
          'Chờ xác minh nạp ${_formatNumber(package.totalCoins)} coins ($transferCode)',
      paymentMethod: paymentMethod,
      packageId: package.id,
      status: TransactionStatus.pending,
      createdAt: DateTime.now(),
    );

    await db.insertTransaction(tx);
    _currentWallet ??= wallet;
    _transactions.insert(0, tx);
    notifyListeners();

    return (
      success: true,
      message: 'Giao dịch đang chờ xác minh thanh toán.',
      transaction: tx,
    );
  }

  /// Reload danh sách packages
  Future<void> refreshPackages() async {
    _packages = await DatabaseHelper.instance.getAllCoinPackages(
      activeOnly: false,
    );
    notifyListeners();
  }

  /// @deprecated Use [createPendingDeposit] and complete the transaction only
  /// after a trusted payment provider confirms the payment.
  Future<({bool success, String message, CoinTransaction? transaction})>
  depositCoins({
    required String userId,
    required CoinPackage package,
    required String paymentMethod,
  }) {
    return createPendingDeposit(
      userId: userId,
      package: package,
      paymentMethod: paymentMethod,
      transferCode: 'LEGACY-${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  /// Chi tiêu coins (mua truyện/chapter)
  Future<({bool success, String message, CoinTransaction? transaction})>
  spendCoins({
    required String userId,
    required int amount,
    required String description,
  }) async {
    if (amount <= 0) {
      return (
        success: false,
        message: 'Số coins phải lớn hơn 0.',
        transaction: null,
      );
    }

    final db = DatabaseHelper.instance;
    final wallet = await db.getWalletByUserId(userId);
    if (wallet == null) {
      return (
        success: false,
        message: 'Không tìm thấy ví của người dùng.',
        transaction: null,
      );
    }

    if (wallet.balance < amount) {
      return (
        success: false,
        message:
            'Số dư không đủ. Cần ${_formatNumber(amount)} coins, hiện có ${_formatNumber(wallet.balance)} coins.',
        transaction: null,
      );
    }

    final newBalance = wallet.balance - amount;
    final newTotalSpent = wallet.totalSpent + amount;

    final tx = CoinTransaction(
      id: const Uuid().v4(),
      userId: userId,
      walletId: wallet.id,
      type: TransactionType.purchase,
      amount: -amount,
      coinsBefore: wallet.balance,
      coinsAfter: newBalance,
      description: description,
      status: TransactionStatus.completed,
      createdAt: DateTime.now(),
    );

    await db.insertTransaction(tx);
    await db.updateWalletBalance(
      userId,
      newBalance,
      wallet.totalEarned,
      newTotalSpent,
    );

    _currentWallet = wallet.copyWith(
      balance: newBalance,
      totalSpent: newTotalSpent,
      updatedAt: DateTime.now(),
    );
    _transactions.insert(0, tx);
    notifyListeners();

    return (
      success: true,
      message:
          'Đã trừ ${_formatNumber(amount)} coins. Số dư: ${_formatNumber(newBalance)}',
      transaction: tx,
    );
  }

  /// Thưởng coins (điểm danh hàng ngày, nhiệm vụ, bonus)
  Future<({bool success, String message, CoinTransaction? transaction})> rewardCoins({
    required String userId,
    required int amount,
    required String description,
  }) async {
    if (amount <= 0) {
      return (success: false, message: 'Số coins thưởng phải lớn hơn 0.', transaction: null);
    }

    final db = DatabaseHelper.instance;
    var wallet = await db.getWalletByUserId(userId);
    if (wallet == null) {
      final now = DateTime.now();
      wallet = Wallet(
        id: 'wallet_$userId',
        userId: userId,
        balance: 0,
        totalEarned: 0,
        totalSpent: 0,
        createdAt: now,
        updatedAt: now,
      );
      await db.insertWallet(wallet);
    }

    final newBalance = wallet.balance + amount;
    final newTotalEarned = wallet.totalEarned + amount;

    final tx = CoinTransaction(
      id: const Uuid().v4(),
      userId: userId,
      walletId: wallet.id,
      type: TransactionType.bonus,
      amount: amount,
      coinsBefore: wallet.balance,
      coinsAfter: newBalance,
      description: description,
      status: TransactionStatus.completed,
      createdAt: DateTime.now(),
    );

    await db.insertTransaction(tx);
    await db.updateWalletBalance(userId, newBalance, newTotalEarned, wallet.totalSpent);

    _currentWallet = wallet.copyWith(
      balance: newBalance,
      totalEarned: newTotalEarned,
      updatedAt: DateTime.now(),
    );
    _transactions.insert(0, tx);
    notifyListeners();

    return (
      success: true,
      message: 'Nhận thành công ${_formatNumber(amount)} coins!',
      transaction: tx,
    );
  }

  /// Reset ví khi logout
  void clearCache() {
    _currentWallet = null;
    _transactions = [];
    notifyListeners();
  }

  /// Format số coins: 1,000,000
  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}
