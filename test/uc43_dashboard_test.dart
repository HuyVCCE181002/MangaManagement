import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manga_management_app/models/admin_stats.dart';
import 'package:manga_management_app/models/coin_transaction.dart';
import 'package:manga_management_app/models/user.dart';
import 'package:manga_management_app/models/wallet.dart';
import 'package:manga_management_app/screens/admin_dashboard_screen.dart';
import 'package:manga_management_app/services/admin_stats_service.dart';
import 'package:manga_management_app/services/auth_service.dart';
import 'package:manga_management_app/services/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.setDbNameForTesting('test_uc43_dashboard.db');
  });

  Future<void> ensureWallet(String userId) async {
    final db = DatabaseHelper.instance;
    if (await db.getWalletByUserId(userId) == null) {
      final now = DateTime.now();
      await db.insertWallet(
        Wallet(
          id: 'wallet_$userId',
          userId: userId,
          balance: 0,
          totalEarned: 0,
          totalSpent: 0,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }

  Future<void> loginAs(String username, String password) async {
    final result = await AuthService.instance.login(username, password);
    expect(result.success, isTrue, reason: result.message);
  }

  Future<void> resetAuthAndDb() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper.instance.resetToDefault();
    await AuthService.instance.logout();
    await AuthService.instance.init();
    await ensureWallet('reader_1');
  }

  CoinTransaction deposit(String id, DateTime createdAt, int vnd) {
    return CoinTransaction(
      id: id,
      userId: 'reader_1',
      walletId: 'wallet_reader_1',
      type: TransactionType.deposit,
      amount: 100,
      coinsBefore: 0,
      coinsAfter: 100,
      description: 'seed',
      paymentAmount: vnd,
      status: TransactionStatus.completed,
      createdAt: createdAt,
    );
  }

  CoinTransaction pending(String id, DateTime createdAt) {
    return CoinTransaction(
      id: id,
      userId: 'reader_1',
      walletId: 'wallet_reader_1',
      type: TransactionType.deposit,
      amount: 0,
      coinsBefore: 0,
      coinsAfter: 0,
      description: 'pending',
      paymentAmount: 10000,
      status: TransactionStatus.pending,
      createdAt: createdAt,
    );
  }

  group('UC-43 Admin View Statistics Dashboard', () {
    setUp(() async {
      await resetAuthAndDb();
    });

    test('UC-43 Admin View Statistics Dashboard: KPI khớp SQLite, filter 7 ngày', () async {
      final db = DatabaseHelper.instance;
      final now = DateTime.now();
      final old = now.subtract(const Duration(days: 10));
      await db.insertTransaction(deposit('dep_old', old, 10000));
      await db.insertTransaction(deposit('dep_new', now, 20000));
      await db.insertTransaction(pending('dep_pen', now));

      final all = await db.getAdminDashboardStats();
      expect(all.completedDeposits, 2);
      expect(all.revenueVnd, 30000);
      expect(all.pendingDeposits, 1);
      expect(all.previousRevenueVnd, 0);
      expect(all.revenueChangeRatio, isNull);

      final recent = await db.getAdminDashboardStats(
        since: now.subtract(const Duration(days: 7)),
      );
      expect(recent.completedDeposits, 1);
      expect(recent.revenueVnd, 20000);
      expect(recent.previousRevenueVnd, 10000);
      expect(recent.revenueChangeRatio, isNotNull);
      expect(
        recent.transactionsByStatus[TransactionStatus.completed.name],
        greaterThanOrEqualTo(1),
      );
      expect(all, isA<AdminDashboardStats>());
    });

    test('UC-43 Admin View Statistics Dashboard: không cộng pending/failed, không chia 0', () async {
      final db = DatabaseHelper.instance;
      final now = DateTime.now();
      await db.insertTransaction(pending('pen_a', now));
      await db.insertTransaction(
        CoinTransaction(
          id: 'fail_a',
          userId: 'reader_1',
          walletId: 'wallet_reader_1',
          type: TransactionType.deposit,
          amount: 0,
          coinsBefore: 0,
          coinsAfter: 0,
          description: 'failed',
          paymentAmount: 50000,
          status: TransactionStatus.failed,
          createdAt: now,
        ),
      );
      final stats = await db.getAdminDashboardStats();
      expect(stats.revenueVnd, 0);
      expect(stats.coinsCredited, 0);
      expect(stats.failedDeposits, 1);
      expect(stats.averageRevenuePerDeposit, 0);
    });

    test('UC-43 Admin View Statistics Dashboard: drill-down trả đúng dữ liệu', () async {
      final db = DatabaseHelper.instance;
      await db.insertTransaction(deposit('dep_d', DateTime.now(), 15000));

      final deps = await db.queryAdminTransactions(
        type: 'deposit',
        statuses: const ['completed'],
        limit: 20,
      );
      expect(deps.length, 1);
      expect(deps.first.id, 'dep_d');

      final users = await db.queryAdminUsers(role: 'reader', limit: 20);
      expect(users, isNotEmpty);
      expect(users.every((u) => u.role == UserRole.reader), isTrue);

      final mangas = await db.queryAdminMangas(limit: 20);
      expect(mangas, isNotEmpty);
    });

    test('UC-43 Admin View Statistics Dashboard: làm mới sau khi dữ liệu thay đổi', () async {
      final db = DatabaseHelper.instance;
      final before = await db.getAdminDashboardStats();
      await db.insertTransaction(deposit('dep_ref', DateTime.now(), 5000));
      final after = await db.getAdminDashboardStats();
      expect(after.revenueVnd, before.revenueVnd + 5000);
      expect(after.completedDeposits, before.completedDeposits + 1);
    });

    test('UC-43 Admin View Statistics Dashboard: cảnh báo có điều kiện rõ ràng', () async {
      final db = DatabaseHelper.instance;
      await db.insertTransaction(
        pending('pen_stale', DateTime.now().subtract(const Duration(hours: 2))),
      );
      final stats = await db.getAdminDashboardStats();
      expect(stats.alerts.any((alert) => alert.id == 'stale_pending'), isTrue);
    });

    test('UC-43 Admin View Statistics Dashboard: service từ chối non-admin', () async {
      await expectLater(
        AdminStatsService.instance.load(),
        throwsA(isA<StateError>()),
      );
      await loginAs('reader', 'reader123');
      await expectLater(
        AdminStatsService.instance.load(),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('UC-43 Admin View Statistics Dashboard UI', () {
    testWidgets('UC-43 Admin View Statistics Dashboard: từ chối reader, staff, guest', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await AuthService.instance.logout();
      await tester.pumpWidget(const MaterialApp(home: AdminDashboardScreen()));
      await tester.pump();
      expect(
        find.text('Chỉ quản trị viên mới xem được dashboard.'),
        findsOneWidget,
      );

      await tester.runAsync(() async {
        await resetAuthAndDb();
        await loginAs('reader', 'reader123');
      });
      await tester.pumpWidget(const MaterialApp(home: AdminDashboardScreen()));
      await tester.pump();
      expect(
        find.text('Chỉ quản trị viên mới xem được dashboard.'),
        findsOneWidget,
      );

      await tester.runAsync(() async {
        await AuthService.instance.logout();
        await loginAs('staff', 'staff123');
      });
      await tester.pumpWidget(const MaterialApp(home: AdminDashboardScreen()));
      await tester.pump();
      expect(
        find.text('Chỉ quản trị viên mới xem được dashboard.'),
        findsOneWidget,
      );
    });

    testWidgets('UC-43 Admin View Statistics Dashboard: admin mở được dashboard', (tester) async {
      await tester.runAsync(() async {
        await resetAuthAndDb();
        await loginAs('admin', 'admin123');
        await tester.pumpWidget(
          const MaterialApp(home: AdminDashboardScreen()),
        );
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 800));
      });
      await tester.pump();
      expect(find.text('Dashboard quản trị'), findsWidgets);
      // Khung filter luôn render ngay cả khi thống kê đang tải.
      expect(find.text('Tất cả'), findsOneWidget);
      expect(find.text('7 ngày'), findsOneWidget);
      expect(find.textContaining('Bộ lọc thời gian'), findsOneWidget);
    });
  });
}
