import 'package:flutter_test/flutter_test.dart';
import 'package:manga_management_app/models/manga.dart';
import 'package:manga_management_app/models/user.dart';
import 'package:manga_management_app/models/payment_order.dart';
import 'package:manga_management_app/models/coin_transaction.dart';
import 'package:manga_management_app/services/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Khởi tạo FFI để test SQLite trên môi trường Dart/Flutter test
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseHelper - Integration Tests (SQLite FFI)', () {
    setUp(() async {
      // Đảm bảo database được reset trước mỗi test
      await DatabaseHelper.instance.resetToDefault();
    });

    test('Seed data chứa 4 users (admin/staff/staff_phat/reader)', () async {
      final users = await DatabaseHelper.instance.getAllUsers();
      expect(users.length, 4);

      final usernames = users.map((u) => u.username).toSet();
      expect(usernames.contains('admin'), isTrue);
      expect(usernames.contains('staff'), isTrue);
      expect(usernames.contains('phatstaff'), isTrue);
      expect(usernames.contains('reader'), isTrue);
    });

    test('Seed data chứa 6 bộ manga', () async {
      final mangas = await DatabaseHelper.instance.getAllMangas();
      expect(mangas.length, 6);
    });

    test('getUserByUsername tìm đúng user (không phân biệt hoa thường)', () async {
      final user = await DatabaseHelper.instance.getUserByUsername('ADMIN');
      expect(user, isNotNull);
      expect(user!.username, 'admin');
      expect(user.role, UserRole.admin);
    });

    test('insertUser thêm user mới với role reader mặc định', () async {
      final newUser = AppUser(
        id: 'new_test_user',
        username: 'newreader',
        displayName: 'New Reader',
        password: 'pass1234',
        role: UserRole.reader,
      );

      final id = await DatabaseHelper.instance.insertUser(newUser);
      expect(id, greaterThan(0));

      final fetched = await DatabaseHelper.instance.getUserById('new_test_user');
      expect(fetched, isNotNull);
      expect(fetched!.displayName, 'New Reader');
    });

    test('updateUserRole cập nhật role thành công', () async {
      final result = await DatabaseHelper.instance.updateUserRole(
        'reader_1',
        UserRole.staff,
      );
      expect(result, 1);

      final user = await DatabaseHelper.instance.getUserById('reader_1');
      expect(user!.role, UserRole.staff);
    });

    test('updateUserPassword đổi mật khẩu thành công', () async {
      final result = await DatabaseHelper.instance.updateUserPassword(
        'admin',
        'newpass999',
      );
      expect(result, 1);

      final user = await DatabaseHelper.instance.getUserByUsername('admin');
      expect(user!.password, 'newpass999');
    });

    test('CRUD Manga: insert -> getById -> update -> delete', () async {
      final manga = Manga(
        id: 'test_manga_99',
        title: 'Test Manga',
        author: 'Test Author',
        description: 'Mô tả test',
        coverUrl: 'https://example.com/cover.jpg',
        genre: 'Action',
        status: 'Ongoing',
        totalChapters: 50,
        currentChapter: 10,
        rating: 8.5,
        isFavorite: false,
      );

      // Insert
      await DatabaseHelper.instance.insertManga(manga);
      final fetched = await DatabaseHelper.instance.getMangaById('test_manga_99');
      expect(fetched, isNotNull);
      expect(fetched!.title, 'Test Manga');

      // Update
      final updated = manga.copyWith(currentChapter: 25, isFavorite: true);
      await DatabaseHelper.instance.updateManga(updated);
      final reFetched = await DatabaseHelper.instance.getMangaById('test_manga_99');
      expect(reFetched!.currentChapter, 25);
      expect(reFetched.isFavorite, isTrue);

      // Delete
      await DatabaseHelper.instance.deleteManga('test_manga_99');
      final deleted = await DatabaseHelper.instance.getMangaById('test_manga_99');
      expect(deleted, isNull);
    });

    test('updateFavorite bật/tắt yêu thích', () async {
      await DatabaseHelper.instance.updateFavorite('1', true);
      var manga = await DatabaseHelper.instance.getMangaById('1');
      expect(manga!.isFavorite, isTrue);

      await DatabaseHelper.instance.updateFavorite('1', false);
      manga = await DatabaseHelper.instance.getMangaById('1');
      expect(manga!.isFavorite, isFalse);
    });

    test('updateChapter cập nhật tiến độ đọc', () async {
      await DatabaseHelper.instance.updateChapter('1', 500);
      final manga = await DatabaseHelper.instance.getMangaById('1');
      expect(manga!.currentChapter, 500);
    });

    test('deleteUser xóa user theo id', () async {
      final result = await DatabaseHelper.instance.deleteUser('reader_1');
      expect(result, 1);
      final user = await DatabaseHelper.instance.getUserById('reader_1');
      expect(user, isNull);
    });

    test('resetToDefault() khôi phục dữ liệu seed', () async {
      // Xóa hết
      await DatabaseHelper.instance.deleteManga('1');
      await DatabaseHelper.instance.deleteManga('2');

      // Reset
      await DatabaseHelper.instance.resetToDefault();

      final mangas = await DatabaseHelper.instance.getAllMangas();
      expect(mangas.length, 6);

      final users = await DatabaseHelper.instance.getAllUsers();
      expect(users.length, 4);
    });

    test('Pending payment does not credit; verified receipt is mirrored once', () async {
      final helper = DatabaseHelper.instance;
      final pkg = (await helper.getAllCoinPackages()).first;
      final now = DateTime.now();
      PaymentOrder receipt(String status) => PaymentOrder(
        id: 'server-order-cache-test', transferCode: 'MANGA0123456789ABCDEF',
        package: pkg, promoCode: '', amount: pkg.price.round(), status: status,
        createdAt: now, expiresAt: now.add(const Duration(minutes: 10)),
        paidAt: status == 'completed' ? now : null,
        bankBin: '970403', accountNumber: '070118746463', accountName: 'NGO VIET TRINH',
      );
      final pending = await helper.cacheServerPayment('reader_1', receipt('pending'));
      expect(pending.status, TransactionStatus.pending);
      expect((await helper.getWalletByUserId('reader_1'))!.balance, 0);
      await Future.wait([
        helper.cacheServerPayment('reader_1', receipt('completed')),
        helper.cacheServerPayment('reader_1', receipt('completed')),
      ]);
      expect((await helper.getWalletByUserId('reader_1'))!.balance, pkg.totalCoins);
      expect((await helper.getTransactionsByUserId('reader_1')).length, 1);
      // A stale response cannot downgrade a completed receipt.
      final stale = await helper.cacheServerPayment('reader_1', receipt('pending'));
      expect(stale.status, TransactionStatus.completed);
      expect((await helper.getWalletByUserId('reader_1'))!.balance, pkg.totalCoins);
    });
  });
}
