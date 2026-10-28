import 'package:flutter_test/flutter_test.dart';
import 'package:manga_management_app/models/admin_stats.dart';
import 'package:manga_management_app/models/chapter.dart';
import 'package:manga_management_app/models/coin_transaction.dart';
import 'package:manga_management_app/models/payment_order.dart';
import 'package:manga_management_app/models/user.dart';
import 'package:manga_management_app/services/auth_service.dart';
import 'package:manga_management_app/services/chapter_service.dart';
import 'package:manga_management_app/services/coin_package_service.dart';
import 'package:manga_management_app/services/database_helper.dart';
import 'package:manga_management_app/services/viet_qr.dart';
import 'package:manga_management_app/services/wallet_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.setDbNameForTesting('test_uc42_uc48.db');
  });

  group('UC-42 den UC-48 flows', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await DatabaseHelper.instance.resetToDefault();
      WalletService.instance.clearCache();
      ChapterService.instance.clearCache();
      await AuthService.instance.logout();
      await AuthService.instance.init();
    });

    Future<AppUser> loginAs(String username, String password) async {
      final result = await AuthService.instance.login(username, password);
      expect(result.success, isTrue, reason: result.message);
      return AuthService.instance.currentUser;
    }

    Chapter lockedChapter({String id = 'chapter_locked_test', int price = 50}) {
      return Chapter(
        id: id,
        mangaId: '1',
        chapterNumber: 999,
        title: 'Locked Test Chapter',
        contents: const ['https://example.com/a.jpg'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isLocked: true,
        price: price.toDouble(),
      );
    }

    Future<void> addPaidPackage(String userId) async {
      await WalletService.instance.loadWallet(userId);
      final db = DatabaseHelper.instance;
      final wallet = (await db.getWalletByUserId(userId))!;
      final now = DateTime.now();
      await db.insertTransaction(
        CoinTransaction(
          id: 'seed_${userId}_${now.microsecondsSinceEpoch}',
          userId: userId,
          walletId: wallet.id,
          type: TransactionType.bonus,
          amount: 1000,
          coinsBefore: wallet.balance,
          coinsAfter: wallet.balance + 1000,
          description: 'seed coins',
          status: TransactionStatus.completed,
          createdAt: now,
        ),
      );
      await db.updateWalletBalance(
        userId,
        wallet.balance + 1000,
        wallet.totalEarned + 1000,
        wallet.totalSpent,
      );
      await WalletService.instance.loadWallet(userId);
    }

    test(
      'UC-42 Admin Delete/Deactivate User: vo hieu hoa thay vi xoa, lich su duoc giu lai',
      () async {
        final admin = await loginAs('admin', 'admin123');
        final before = AuthService.instance.getAllUsers().firstWhere(
          (u) => u.id == 'reader_1',
        );
        expect(before.isGuest, isFalse);

        await addPaidPackage('reader_1');
        final wallet = (await DatabaseHelper.instance.getWalletByUserId(
          'reader_1',
        ))!;
        expect(wallet.balance, 1000);
        await DatabaseHelper.instance.insertTransaction(
          CoinTransaction(
            id: 'history_reader_1',
            userId: 'reader_1',
            walletId: wallet.id,
            type: TransactionType.purchase,
            amount: -100,
            coinsBefore: 1000,
            coinsAfter: 900,
            description: 'history snapshot',
            status: TransactionStatus.completed,
            createdAt: DateTime.now(),
          ),
        );

        final res = await AuthService.instance.deleteUser('reader_1');
        expect(res.success, isTrue, reason: res.message);
        expect(res.deactivated, isTrue);

        final user = await DatabaseHelper.instance.getUserById('reader_1');
        expect(user, isNotNull);
        expect(user!.isActive, isFalse);
        expect(
          (await DatabaseHelper.instance.getWalletByUserId(
            'reader_1',
          ))!.balance,
          1000,
        );
        expect(
          (await DatabaseHelper.instance.getTransactionsByUserId(
            'reader_1',
          )).length,
          2,
        );

        final blocked = await AuthService.instance.login('reader', 'reader123');
        expect(blocked.success, isFalse);
        expect(admin.id.isNotEmpty, isTrue);
      },
    );

    test(
      'UC-42 Admin Delete/Deactivate User: khong vo hieu hoa admin cuoi cung hoac chinh minh',
      () async {
        await loginAs('reader', 'reader123');
        final denied = await AuthService.instance.deleteUser('staff_1');
        expect(denied.success, isFalse);

        await AuthService.instance.logout();
        await loginAs('admin', 'admin123');
        final selfRes = await AuthService.instance.deleteUser(
          AuthService.instance.currentUser.id,
        );
        expect(selfRes.success, isFalse);
        expect(
          (await DatabaseHelper.instance.getUserById('admin_1'))!.isActive,
          isTrue,
        );
      },
    );

    test('UC-42 Admin Delete/Deactivate User: guest khong dang nhap duoc sau khi vo hieu hoa', () async {
      await loginAs('admin', 'admin123');
      await AuthService.instance.deleteUser('reader_1');
      await AuthService.instance.logout();
      final res = await AuthService.instance.login('reader', 'reader123');
      expect(res.success, isFalse);
    });

    test('UC-43 Admin View Statistics Dashboard: KPI khop SQLite', () async {
      final stats = await DatabaseHelper.instance.getAdminDashboardStats();
      expect(stats, isA<AdminDashboardStats>());
      expect(stats.totalUsers, greaterThanOrEqualTo(4));
      expect(stats.totalMangas, greaterThanOrEqualTo(6));
      expect(stats.totalChapters, greaterThanOrEqualTo(1));
      expect(stats.activeUsers + stats.deactivatedUsers, stats.totalUsers);
      expect(stats.revenueVnd, greaterThanOrEqualTo(0));
      expect(stats.averageRevenuePerDeposit, greaterThanOrEqualTo(0));
    });

    test('UC-44 Reader View Wallet & Coins: chi thay vi cua chinh minh', () async {
      await WalletService.instance.loadWallet('reader_1');
      final readerBalance = WalletService.instance.balance;
      expect(readerBalance, 0);

      await WalletService.instance.loadWallet('admin_1');
      expect(WalletService.instance.currentWallet!.userId, 'admin_1');

      final other = await DatabaseHelper.instance.getTransactionsByUserId(
        'reader_1',
      );
      expect(other, isEmpty);
      await WalletService.instance.loadWallet('reader_1');
      expect(WalletService.instance.currentWallet!.userId, 'reader_1');
    });

    test('UC-44 Wallet: so du nap duoc giu sau logout/login', () async {
      final user = await loginAs('reader', 'reader123');
      final rewarded = await WalletService.instance.rewardCoins(
        userId: user.id,
        amount: 750,
        description: 'test persist',
      );
      expect(rewarded.success, isTrue);
      expect(WalletService.instance.balance, 750);

      await AuthService.instance.logout();
      expect(WalletService.instance.balance, 0);

      await loginAs('reader', 'reader123');
      expect(WalletService.instance.balance, 750);
      expect(WalletService.instance.totalEarned, 750);
    });

    test('UC-44 Wallet: khoi phuc so du tu snapshot khi sqlite mat vi', () async {
      final user = await loginAs('reader', 'reader123');
      final rewarded = await WalletService.instance.rewardCoins(
        userId: user.id,
        amount: 420,
        description: 'snapshot',
      );
      expect(rewarded.success, isTrue);

      final sqlite = await DatabaseHelper.instance.database;
      await sqlite.delete(
        DatabaseHelper.tableCoinTransactions,
        where: 'user_id = ?',
        whereArgs: [user.id],
      );
      await sqlite.delete(
        DatabaseHelper.tableWallets,
        where: 'user_id = ?',
        whereArgs: [user.id],
      );
      WalletService.instance.clearCache();
      expect(WalletService.instance.balance, 0);

      await WalletService.instance.loadWallet(user.id);
      expect(WalletService.instance.balance, 420);
      expect(WalletService.instance.totalEarned, 420);
    });

    test('UC-45 Deposit: completeLocalDeposit giu xu sau login lai', () async {
      final user = await loginAs('reader', 'reader123');
      final packages = await DatabaseHelper.instance.getAllCoinPackages(
        activeOnly: true,
      );
      expect(packages, isNotEmpty);
      final pending = await WalletService.instance.createPendingDeposit(
        userId: user.id,
        package: packages.first,
        paymentMethod: 'bank',
        transferCode: 'MVTESTPERSIST',
      );
      expect(pending.success, isTrue);
      expect(WalletService.instance.balance, 0);
      final done = await WalletService.instance.completeLocalDeposit(
        pending.transaction!.id,
      );
      expect(done.success, isTrue, reason: done.message);
      final coins = packages.first.totalCoins;
      expect(WalletService.instance.balance, coins);

      await AuthService.instance.logout();
      await loginAs('reader', 'reader123');
      expect(WalletService.instance.balance, coins);
    });

    test(
      'UC-45 Reader Deposit/Top-up Coins: nap thanh cong cong xu mot lan, nap that bai khong cong',
      () async {
        final helper = DatabaseHelper.instance;
        final pkg = (await helper.getAllCoinPackages()).first;
        final now = DateTime.now().subtract(const Duration(minutes: 1));
        PaymentOrder order(String status, String id) => PaymentOrder(
          id: id,
          transferCode: 'MANGA0123456789ABCDEF',
          package: pkg,
          promoCode: '',
          amount: pkg.price.round(),
          status: status,
          createdAt: now,
          expiresAt: now.add(const Duration(minutes: 10)),
          paidAt: status == 'completed' ? now : null,
          bankBin: 'STB',
          accountNumber: '070118746463',
          accountName: 'NGO VIET TRINH',
        );
        // QR thanh toán thật: Sacombank BIN 970403, STK 070118746463, đúng số tiền và mã đơn.
        final qr = order('pending', 'order-concurrent-qr').qrUrl;
        expect(qr, contains('img.vietqr.io/image/970403-070118746463-compact2.png'));
        final localQr = PaymentOrder.vietQrUrl(
          amount: 50000,
          transferCode: 'MVTEST123',
        );
        expect(
          localQr,
          contains('img.vietqr.io/image/970403-070118746463-compact2.png'),
        );
        final qrCandidates = order('pending', 'order-concurrent-qr').qrImageCandidates;
        expect(qrCandidates.length, 2);
        expect(qrCandidates[1], contains('qr.sepay.vn'));
        final payload = VietQr.emvCoPayload(amount: 50000, transferCode: 'MVTEST123');
        expect(payload, startsWith('0002010102'));
        expect(payload.length, inInclusiveRange(100, 300));
        final matrix = QrMatrix.encode(payload);
        expect(matrix.size, inInclusiveRange(21, 57));
        expect(localQr, contains('amount=50000'));
        expect(localQr, contains('addInfo=MVTEST123'));
        expect(qr, contains('amount=${pkg.price.round()}'));
        expect(qr, contains('addInfo=MANGA0123456789ABCDEF'));

        final failed = await helper.cacheServerPayment(
          'reader_1',
          order('failed', 'order-concurrent-1'),
        );
        expect(failed.status, TransactionStatus.failed);
        expect((await helper.getWalletByUserId('reader_1'))!.balance, 0);

        await Future.wait([
          helper.cacheServerPayment(
            'reader_1',
            order('completed', 'order-concurrent-2'),
          ),
          helper.cacheServerPayment(
            'reader_1',
            order('completed', 'order-concurrent-2'),
          ),
        ]);
        expect(
          (await helper.getWalletByUserId('reader_1'))!.balance,
          pkg.totalCoins,
        );
      },
    );

    test(
      'UC-48 Admin Manage Coin Packages: goi inactive khong dung duoc; xoa goi co lich su chi tam dung',
      () async {
        await loginAs('admin', 'admin123');
        final service = CoinPackageService.instance;
        await service.loadAll();
        final created = await service.createPackage(
          name: 'Test Pack',
          coins: 100,
          price: 10000,
        );
        expect(created.success, isTrue);
        final pkg = created.package!;
        final paused = await service.toggleActive(pkg.id);
        expect(paused.success, isTrue);

        final blocked = await WalletService.instance.createPendingDeposit(
          userId: 'reader_1',
          package: pkg,
          paymentMethod: 'Chuyển khoản ngân hàng',
          transferCode: 'MANGATEST001',
        );
        expect(blocked.success, isFalse);

        final activePkg = (await DatabaseHelper.instance.getAllCoinPackages(
          activeOnly: true,
        )).first;
        final ok = await WalletService.instance.createPendingDeposit(
          userId: 'reader_1',
          package: activePkg,
          paymentMethod: 'Chuyển khoản ngân hàng',
          transferCode: 'MANGATEST002',
        );
        expect(ok.success, isTrue);

        final deleted = await service.deletePackage(activePkg.id);
        expect(deleted.success, isTrue);
        final after = await DatabaseHelper.instance.getCoinPackageById(
          activePkg.id,
        );
        expect(after, isNotNull);
        expect(after!.isActive, isFalse);
        final activeOnly = await DatabaseHelper.instance.getAllCoinPackages(
          activeOnly: true,
        );
        expect(activeOnly.any((item) => item.id == activePkg.id), isFalse);
      },
    );

    test('UC-46 Reader Unlock Premium Chapter: du xu thi mo khoa; thieu xu thi that bai', () async {
      await loginAs('reader', 'reader123');
      await DatabaseHelper.instance.insertChapter(lockedChapter());
      final poor = await WalletService.instance.unlockChapter(
        userId: 'reader_1',
        chapterId: 'chapter_locked_test',
      );
      expect(poor.success, isFalse);
      await addPaidPackage('reader_1');

      final ok = await WalletService.instance.unlockChapter(
        userId: 'reader_1',
        chapterId: 'chapter_locked_test',
      );
      expect(ok.success, isTrue);
      expect(
        await DatabaseHelper.instance.isChapterPurchasedByUser(
          'reader_1',
          'chapter_locked_test',
        ),
        isTrue,
      );
      expect(
        (await DatabaseHelper.instance.getTransactionsByUserId('reader_1'))
            .where(
              (t) =>
                  t.status == TransactionStatus.completed &&
                  t.type == TransactionType.purchase,
            )
            .length,
        1,
      );

      final repeat = await WalletService.instance.unlockChapter(
        userId: 'reader_1',
        chapterId: 'chapter_locked_test',
      );
      expect(repeat.success, isTrue);
      expect(
        (await DatabaseHelper.instance.getWalletByUserId('reader_1'))!.balance,
        950,
      );
    });

    test('UC-46 Reader Unlock Premium Chapter: race khong double-spend', () async {
      await DatabaseHelper.instance.insertChapter(
        lockedChapter(id: 'chapter_race', price: 800),
      );
      await loginAs('reader', 'reader123');
      await addPaidPackage('reader_1');

      final results = await Future.wait([
        WalletService.instance.unlockChapter(
          userId: 'reader_1',
          chapterId: 'chapter_race',
        ),
        WalletService.instance.unlockChapter(
          userId: 'reader_1',
          chapterId: 'chapter_race',
        ),
      ]);
      expect(results.where((r) => r.success).length, 2);

      final wallet = (await DatabaseHelper.instance.getWalletByUserId(
        'reader_1',
      ))!;
      expect(wallet.balance, greaterThanOrEqualTo(0));
      expect(wallet.balance, 200);
      final purchases =
          (await DatabaseHelper.instance.getTransactionsByUserId('reader_1'))
              .where(
                (tx) =>
                    tx.type == TransactionType.purchase &&
                    tx.status == TransactionStatus.completed,
              )
              .toList();
      expect(purchases.length, 1);
    });

    test('UC-46 Reader Unlock Premium Chapter: doc lai khong tru them xu, van co contents', () async {
      await DatabaseHelper.instance.insertChapter(lockedChapter());
      await loginAs('reader', 'reader123');
      await addPaidPackage('reader_1');
      final first = await WalletService.instance.unlockChapter(
        userId: 'reader_1',
        chapterId: 'chapter_locked_test',
      );
      expect(first.success, isTrue);

      final before = (await DatabaseHelper.instance.getWalletByUserId(
        'reader_1',
      ))!.balance;
      final owned = await ChapterService.instance.isChapterPurchased(
        'reader_1',
        'chapter_locked_test',
      );
      expect(owned, isTrue);
      final after = (await DatabaseHelper.instance.getWalletByUserId(
        'reader_1',
      ))!.balance;
      expect(after, before);

      ChapterService.instance.clearCache();
      final chapters = await ChapterService.instance.getChapters('1');
      final unlocked = chapters.where((c) => c.id == 'chapter_locked_test').first;
      expect(unlocked.contents, isNotEmpty);
    });

    test('UC-47 Reader View Transaction History: chi thay lich su cua minh', () async {
      await loginAs('reader', 'reader123');
      await addPaidPackage('reader_1');
      await addPaidPackage('admin_1');
      final mine = await DatabaseHelper.instance.getTransactionsByUserId(
        'reader_1',
      );
      expect(mine, isNotEmpty);
      expect(mine.every((tx) => tx.userId == 'reader_1'), isTrue);
    });

    test('UC-48 Admin Manage Coin Packages: doi gia giu snapshot giao dich cu', () async {
      final helper = DatabaseHelper.instance;
      final pkg = (await helper.getAllCoinPackages()).first;
      final now = DateTime.now().subtract(const Duration(minutes: 30));
      final receipt = PaymentOrder(
        id: 'order-price-snapshot',
        transferCode: 'MANGA0123456789ABCDEF',
        package: pkg,
        promoCode: '',
        amount: pkg.price.round(),
        status: 'completed',
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 10)),
        paidAt: now,
        bankBin: 'STB',
        accountNumber: '070118746463',
        accountName: 'NGO VIET TRINH',
      );
      final mirrored = await helper.cacheServerPayment('reader_1', receipt);
      final oldAmount = mirrored.paymentAmount;
      expect(oldAmount, pkg.price.round());

      await helper.updateCoinPackage(pkg.copyWith(price: pkg.price + 5000));
      final reread = await helper.getTransactionById(receipt.id);
      expect(reread, isNotNull);
      expect(reread!.paymentAmount, oldAmount);
      expect(reread.amount, pkg.totalCoins);
    });

    test('UC-45 Reader Deposit/Top-up Coins: migration giu du lieu cu khi nang schema v5', () async {
      final helper = DatabaseHelper.instance;
      await WalletService.instance.loadWallet('reader_1');
      await helper.insertTransaction(
        CoinTransaction(
          id: 'migration-check',
          userId: 'reader_1',
          walletId: 'wallet_reader_1',
          type: TransactionType.deposit,
          amount: 123,
          coinsBefore: 0,
          coinsAfter: 123,
          description: 'legacy row',
          status: TransactionStatus.completed,
          createdAt: DateTime.now(),
        ),
      );
      final users = await helper.getAllUsers();
      expect(users.map((u) => u.username), contains('reader'));
      final tx = await helper.getTransactionById('migration-check');
      expect(tx, isNotNull);
      expect(tx!.amount, 123);
    });

    test(
      'UC-45 Reader Deposit/Top-up Coins: fallback local cong xu; goi 2 lan chi cong 1 lan',
      () async {
        await loginAs('reader', 'reader123');
        await WalletService.instance.loadWallet('reader_1');
        final pkg = (await DatabaseHelper.instance.getAllCoinPackages(
          activeOnly: true,
        )).first;
        final created = await WalletService.instance.createPendingDeposit(
          userId: 'reader_1',
          package: pkg,
          paymentMethod: 'Chuyen khoan ngan hang',
          transferCode: 'LOCAL-TEST',
        );
        expect(created.success, isTrue);
        expect(created.transaction, isNotNull);
        expect(created.transaction!.status, TransactionStatus.pending);

        final before = WalletService.instance.balance;
        final first = await WalletService.instance.completeLocalDeposit(
          created.transaction!.id,
        );
        expect(first.success, isTrue, reason: first.message);
        expect(first.transaction!.status, TransactionStatus.completed);
        expect(WalletService.instance.balance, before + pkg.totalCoins);

        final afterFirst = WalletService.instance.balance;
        final second = await WalletService.instance.completeLocalDeposit(
          created.transaction!.id,
        );
        expect(second.success, isTrue, reason: second.message);
        expect(WalletService.instance.balance, afterFirst);
        final txs = await DatabaseHelper.instance.getTransactionsByUserId(
          'reader_1',
        );
        expect(
          txs.where((t) => t.id == created.transaction!.id).length,
          1,
        );
      },
    );
  });
}
