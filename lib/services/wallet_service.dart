import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  static const _snapshotPrefix = 'manga_vault_wallet_snapshot_v1_';

  bool _hasCompletedMoney(List<CoinTransaction> txs) {
    return txs.any(
      (tx) =>
          tx.status == TransactionStatus.completed &&
          (tx.type == TransactionType.deposit ||
              tx.type == TransactionType.bonus ||
              tx.type == TransactionType.purchase ||
              tx.type == TransactionType.refund ||
              tx.type == TransactionType.spending),
    );
  }

  Future<void> _saveSnapshot(String userId) async {
    final wallet = _currentWallet;
    if (wallet == null || wallet.userId != userId) return;
    if (wallet.balance == 0 &&
        wallet.totalEarned == 0 &&
        wallet.totalSpent == 0 &&
        !_hasCompletedMoney(_transactions)) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_snapshotPrefix$userId',
      jsonEncode({
        'wallet': wallet.toMap(),
        'transactions': _transactions.map((tx) => tx.toMap()).toList(),
      }),
    );
  }

  Future<bool> _restoreSnapshot(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_snapshotPrefix$userId');
    if (raw == null || raw.isEmpty) return false;
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return false;
      final walletRaw = data['wallet'];
      final txRaw = data['transactions'];
      if (walletRaw is! Map || txRaw is! List) return false;
      final wallet = Wallet.fromMap(Map<String, dynamic>.from(walletRaw));
      if (wallet.userId != userId) return false;
      final transactions = txRaw
          .whereType<Map>()
          .map((item) => CoinTransaction.fromMap(Map<String, dynamic>.from(item)))
          .where((tx) => tx.userId == userId)
          .toList();
      if (wallet.balance == 0 &&
          wallet.totalEarned == 0 &&
          !_hasCompletedMoney(transactions)) {
        return false;
      }
      await DatabaseHelper.instance.restoreWalletSnapshot(
        wallet: wallet,
        transactions: transactions,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Load ví và giao dịch của user hiện tại
  Future<void> loadWallet(String userId) async {
    final db = DatabaseHelper.instance;

    var wallet = await db.getWalletByUserId(userId);
    var transactions = wallet == null
        ? <CoinTransaction>[]
        : await db.getTransactionsByUserId(userId);
    if (!_hasCompletedMoney(transactions)) {
      final restored = await _restoreSnapshot(userId);
      if (restored) {
        wallet = await db.getWalletByUserId(userId);
        transactions = await db.getTransactionsByUserId(userId);
      }
    }
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
    _transactions = transactions;
    _packages = await db.getAllCoinPackages(activeOnly: true);
    await _saveSnapshot(userId);
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

  /// UC-45: hoàn tất nạp xu trên app khi payment server tắt / demo.
  /// Cùng transactionId gọi 2 lần chỉ cộng xu 1 lần.
  Future<({bool success, String message, CoinTransaction? transaction})>
  completeLocalDeposit(String transactionId) async {
    try {
      final tx = await DatabaseHelper.instance.completeLocalDeposit(
        transactionId,
      );
      await loadWallet(tx.userId);
      return (
        success: true,
        message: 'Đã cộng ${tx.amount} coins vào ví.',
        transaction: tx,
      );
    } on StateError catch (e) {
      return (success: false, message: e.message, transaction: null);
    }
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

    final livePackage = await db.getCoinPackageById(package.id);
    if (livePackage == null || !livePackage.isActive) {
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
              tx.packageId == livePackage.id &&
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
      amount: livePackage.totalCoins,
      coinsBefore: wallet.balance,
      coinsAfter: wallet.balance,
      description:
          'Chờ xác minh nạp ${_formatNumber(livePackage.totalCoins)} coins ($transferCode)',
      paymentMethod: paymentMethod,
      packageId: livePackage.id,
      paymentAmount: livePackage.price.round(),
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

    final sqlite = await db.database;
    try {
      await sqlite.transaction((txn) async {
        final wallets = await txn.query(
          DatabaseHelper.tableWallets,
          where: 'user_id = ?',
          whereArgs: [userId],
          limit: 1,
        );
        if (wallets.isEmpty) {
          throw StateError('missing_wallet');
        }
        final live = Wallet.fromMap(wallets.first);
        if (live.balance < amount) {
          throw StateError('insufficient');
        }
        final spentBalance = live.balance - amount;
        final spentTotal = live.totalSpent + amount;
        final updated = await txn.update(
          DatabaseHelper.tableWallets,
          {
            'balance': spentBalance,
            'total_spent': spentTotal,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'user_id = ? AND balance >= ?',
          whereArgs: [userId, amount],
        );
        if (updated == 0) {
          throw StateError('insufficient');
        }
        await txn.insert(
          DatabaseHelper.tableCoinTransactions,
          tx
              .copyWith(
                coinsBefore: live.balance,
                coinsAfter: spentBalance,
                amount: -amount,
              )
              .toMap(),
        );
      });
    } on StateError catch (e) {
      if (e.message == 'insufficient') {
        final liveWallet = await db.getWalletByUserId(userId);
        return (
          success: false,
          message:
              'Số dư không đủ. Hiện có ${_formatNumber(liveWallet?.balance ?? 0)} coins.',
          transaction: null,
        );
      }
      return (
        success: false,
        message: 'Không tìm thấy ví của người dùng.',
        transaction: null,
      );
    }

    await loadWallet(userId);

    return (
      success: true,
      message:
          'Đã trừ ${_formatNumber(amount)} coins. Số dư: ${_formatNumber(newBalance)}',
      transaction: tx,
    );
  }

  /// Thưởng coins (điểm danh hàng ngày, nhiệm vụ, bonus)
  Future<({bool success, String message, CoinTransaction? transaction})>
  rewardCoins({
    required String userId,
    required int amount,
    required String description,
  }) async {
    if (amount <= 0) {
      return (
        success: false,
        message: 'Số coins thưởng phải lớn hơn 0.',
        transaction: null,
      );
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
    await db.updateWalletBalance(
      userId,
      newBalance,
      newTotalEarned,
      wallet.totalSpent,
    );

    _currentWallet = wallet.copyWith(
      balance: newBalance,
      totalEarned: newTotalEarned,
      updatedAt: DateTime.now(),
    );
    _transactions.insert(0, tx);
    await _saveSnapshot(userId);
    notifyListeners();

    return (
      success: true,
      message: 'Nhận thành công ${_formatNumber(amount)} coins!',
      transaction: tx,
    );
  }

  /// Mở khóa chương: trừ xu và ghi quyền sở hữu trong cùng một transaction.
  Future<({bool success, String message, bool alreadyOwned})> unlockChapter({
    required String userId,
    required String chapterId,
  }) async {
    if (userId.isEmpty || userId == 'guest') {
      return (
        success: false,
        message: 'Vui lòng đăng nhập để mở khóa chương.',
        alreadyOwned: false,
      );
    }
    final result = await DatabaseHelper.instance.unlockChapter(
      userId: userId,
      chapterId: chapterId,
    );
    if (result.success) {
      await loadWallet(userId);
    }
    return result;
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
