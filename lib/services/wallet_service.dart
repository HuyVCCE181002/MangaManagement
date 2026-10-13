import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/wallet.dart';
import '../models/coin_transaction.dart';
import '../models/coin_package.dart';
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
    _transactions = await DatabaseHelper.instance.getTransactionsByUserId(_currentWallet!.userId);
    notifyListeners();
  }

  /// Reload danh sách packages
  Future<void> refreshPackages() async {
    _packages = await DatabaseHelper.instance.getAllCoinPackages(activeOnly: false);
    notifyListeners();
  }

  /// Nạp coins (mua gói)
  Future<({bool success, String message, CoinTransaction? transaction})> depositCoins({
    required String userId,
    required CoinPackage package,
    required String paymentMethod,
  }) async {
    final db = DatabaseHelper.instance;

    // 1. Lấy ví hiện tại
    final wallet = await db.getWalletByUserId(userId);
    if (wallet == null) {
      return (success: false, message: 'Không tìm thấy ví của người dùng.', transaction: null);
    }

    if (!package.isActive) {
      return (success: false, message: 'Gói coins này hiện không khả dụng.', transaction: null);
    }

    final totalCoins = package.totalCoins;
    final newBalance = wallet.balance + totalCoins;
    final newTotalEarned = wallet.totalEarned + totalCoins;

    // 2. Tạo giao dịch (pending trước)
    final tx = CoinTransaction(
      id: const Uuid().v4(),
      userId: userId,
      type: TransactionType.deposit,
      amount: totalCoins,
      coinsBefore: wallet.balance,
      coinsAfter: newBalance,
      description: 'Nạp ${_formatNumber(totalCoins)} coins từ gói "${package.name}"',
      paymentMethod: paymentMethod,
      packageId: package.id,
      status: TransactionStatus.pending,
      createdAt: DateTime.now(),
    );

    await db.insertTransaction(tx);

    // 3. Mô phỏng xử lý thanh toán
    // Trong thực tế sẽ gọi payment gateway, ở đây giả lập thành công
    await Future.delayed(const Duration(milliseconds: 800));

    // 4. Cập nhật ví
    await db.updateWalletBalance(userId, newBalance, newTotalEarned, wallet.totalSpent);

    // 5. Cập nhật giao dịch -> completed
    await db.updateTransactionStatus(tx.id, TransactionStatus.completed);
    final completedTx = tx.copyWith(status: TransactionStatus.completed);

    // 6. Update local cache
    _currentWallet = wallet.copyWith(
      balance: newBalance,
      totalEarned: newTotalEarned,
      updatedAt: DateTime.now(),
    );
    _transactions.insert(0, completedTx);
    notifyListeners();

    return (
      success: true,
      message: 'Nạp thành công ${_formatNumber(totalCoins)} coins!',
      transaction: completedTx,
    );
  }

  /// Chi tiêu coins (mua truyện/chapter)
  Future<({bool success, String message, CoinTransaction? transaction})> spendCoins({
    required String userId,
    required int amount,
    required String description,
  }) async {
    if (amount <= 0) {
      return (success: false, message: 'Số coins phải lớn hơn 0.', transaction: null);
    }

    final db = DatabaseHelper.instance;
    final wallet = await db.getWalletByUserId(userId);
    if (wallet == null) {
      return (success: false, message: 'Không tìm thấy ví của người dùng.', transaction: null);
    }

    if (wallet.balance < amount) {
      return (
        success: false,
        message: 'Số dư không đủ. Cần ${_formatNumber(amount)} coins, hiện có ${_formatNumber(wallet.balance)} coins.',
        transaction: null,
      );
    }

    final newBalance = wallet.balance - amount;
    final newTotalSpent = wallet.totalSpent + amount;

    final tx = CoinTransaction(
      id: const Uuid().v4(),
      userId: userId,
      type: TransactionType.purchase,
      amount: -amount,
      coinsBefore: wallet.balance,
      coinsAfter: newBalance,
      description: description,
      status: TransactionStatus.completed,
      createdAt: DateTime.now(),
    );

    await db.insertTransaction(tx);
    await db.updateWalletBalance(userId, newBalance, wallet.totalEarned, newTotalSpent);

    _currentWallet = wallet.copyWith(
      balance: newBalance,
      totalSpent: newTotalSpent,
      updatedAt: DateTime.now(),
    );
    _transactions.insert(0, tx);
    notifyListeners();

    return (
      success: true,
      message: 'Đã trừ ${_formatNumber(amount)} coins. Số dư: ${_formatNumber(newBalance)}',
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
