// Conditional imports: chọn factory theo nền tảng (web vs non-web)
import 'package:flutter/foundation.dart';
import 'database_factory_io.dart' if (dart.library.html) 'database_factory_web.dart';
import '../models/bookmark.dart';
import '../models/chapter.dart';
import '../models/manga.dart';
import '../models/user.dart';
import '../models/wallet.dart';
import '../models/coin_transaction.dart';
import '../models/coin_package.dart';
import '../models/payment_order.dart';

class DatabaseHelper {
  static const String _dbName = 'manga_vault.db';
  // Lịch sử version:
  //   v1: users + mangas (bản đầu)
  //   v2: thêm chapters + user_purchased_chapters + bookmarks
  //   v3: thêm wallets + coin_transactions + coin_packages
  // v4: thêm wallet_id cho coin_transactions (sửa lỗi NOT NULL khi schema cache cũ)
  static const int _dbVersion = 4;

  static const String tableUsers = 'users';
  static const String tableMangas = 'mangas';
  static const String tableGenres = 'genres';
  static const String tableChapters = 'chapters';
  static const String tableUserPurchasedChapters = 'user_purchased_chapters';
  static const String tableBookmarks = 'bookmarks';
  static const String tableWallets = 'wallets';
  static const String tableCoinTransactions = 'coin_transactions';
  static const String tableCoinPackages = 'coin_packages';

  static final DatabaseHelper instance = DatabaseHelper._internal();
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Khởi tạo database factory theo nền tảng
    setupPlatformDatabase();

    // Lấy đường dẫn database theo nền tảng
    final path = await resolveDatabasePath(_dbName);

    final db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    // Đảm bảo tài khoản Staff yêu cầu luôn sẵn sàng ngay cả trên DB đã tồn tại
    await _ensureRequiredAccounts(db);

    return db;
  }

  Future<void> _ensureRequiredAccounts(Database db) async {
    // Đảm bảo cột avatar_url luôn tồn tại trong bảng users
    await _addColumnIfMissing(db, tableUsers, 'avatar_url', 'TEXT');

    // Đảm bảo bảng user_purchased_chapters luôn tồn tại
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableUserPurchasedChapters (
        user_id TEXT NOT NULL,
        chapter_id TEXT NOT NULL,
        purchased_at TEXT NOT NULL,
        PRIMARY KEY (user_id, chapter_id),
        FOREIGN KEY (user_id) REFERENCES $tableUsers (id) ON DELETE CASCADE,
        FOREIGN KEY (chapter_id) REFERENCES $tableChapters (id) ON DELETE CASCADE
      )
    ''');

    // Đảm bảo bảng bookmarks luôn tồn tại
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableBookmarks (
        user_id TEXT NOT NULL,
        manga_id TEXT NOT NULL,
        chapter_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        PRIMARY KEY (user_id, manga_id),
        FOREIGN KEY (user_id) REFERENCES $tableUsers (id) ON DELETE CASCADE,
        FOREIGN KEY (manga_id) REFERENCES $tableMangas (id) ON DELETE CASCADE,
        FOREIGN KEY (chapter_id) REFERENCES $tableChapters (id) ON DELETE CASCADE
      )
    ''');

    // Đảm bảo các bảng coin luôn tồn tại
    await _createCoinTables(db);
    await _addColumnIfMissing(db, tableCoinTransactions, 'user_id', 'TEXT');
    await _addColumnIfMissing(db, tableCoinTransactions, 'coins_before', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, tableCoinTransactions, 'coins_after', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, tableCoinTransactions, 'payment_method', 'TEXT');
    await _addColumnIfMissing(db, tableCoinTransactions, 'package_id', 'TEXT');

    // Đảm bảo bảng user_check_in_stats luôn tồn tại
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableUserCheckInStats (
        user_id TEXT PRIMARY KEY,
        last_check_in_date TEXT NOT NULL,
        current_streak INTEGER NOT NULL DEFAULT 0,
        total_check_ins INTEGER NOT NULL DEFAULT 0,
        total_reward_coins INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES $tableUsers (id) ON DELETE CASCADE
      )
    ''');

    // Đảm bảo bảng daily_check_in_history luôn tồn tại
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableDailyCheckInHistory (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        check_in_date TEXT NOT NULL,
        streak_day INTEGER NOT NULL,
        reward_coins INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES $tableUsers (id) ON DELETE CASCADE
      )
    ''');

    const phatStaff = AppUser(
      id: 'staff_phat',
      username: 'phatstaff',
      displayName: 'Nhân Viên Phát (Staff)',
      password: '123456',
      role: UserRole.staff,
    );
    await db.insert(
      tableUsers,
      phatStaff.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _createCoinTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableWallets (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL UNIQUE,
        balance INTEGER NOT NULL DEFAULT 0,
        total_earned INTEGER NOT NULL DEFAULT 0,
        total_spent INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES $tableUsers (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTransactions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        coins_before INTEGER NOT NULL,
        coins_after INTEGER NOT NULL,
        description TEXT NOT NULL,
        payment_method TEXT,
        package_id TEXT,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES $tableUsers (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableCoinPackages (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        coins INTEGER NOT NULL,
        price REAL NOT NULL,
        bonus_coins INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        is_featured INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _seedCoinPackages(Database db) async {
    final now = DateTime.now();
    final packages = [
      CoinPackage(id: 'pkg_starter', name: 'Gói Starter', coins: 100, price: 10000, sortOrder: 1, createdAt: now),
      CoinPackage(id: 'pkg_standard', name: 'Gói Standard', coins: 550, price: 50000, bonusCoins: 50, isFeatured: true, sortOrder: 2, createdAt: now),
      CoinPackage(id: 'pkg_vip', name: 'Gói VIP', coins: 1200, price: 100000, bonusCoins: 200, sortOrder: 3, createdAt: now),
    ];
    for (final package in packages) {
      await db.insert(tableCoinPackages, package.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v1 -> v2: thêm chapters + bookmarks + user_purchased_chapters
    if (oldVersion < 2) {
      await _createChapterTables(db);
      await _seedChaptersData(db);
    }
    // v2 -> v3: thêm coin/wallet tables + seed packages
    if (oldVersion < 3) {
      await _createCoinTables(db);
      await _seedCoinPackages(db);
      await _createGenreTable(db);
    }
    if (oldVersion < 4) {
      await _createGenreTable(db);
      await _addColumnIfMissing(db, tableMangas, 'is_hidden', 'INTEGER NOT NULL DEFAULT 0');
    }
    // v3 -> v4: ALTER TABLE coin_transactions thêm wallet_id
    //   - Sửa lỗi NOT NULL constraint failed trên web cache
    if (oldVersion < 4) {
      try {
        // Kiểm tra xem cột wallet_id đã tồn tại chưa
        final cols = await db.rawQuery('PRAGMA table_info(coin_transactions)');
        final hasWalletId = cols.any((c) => c['name'] == 'wallet_id');
        if (!hasWalletId) {
          // Backfill wallet_id cho tất cả transactions cũ dựa vào user_id
          await db.execute('''
            UPDATE $tableCoinTransactions
            SET wallet_id = 'wallet_' || user_id
            WHERE wallet_id IS NULL OR wallet_id = ''
          ''');
          // Thêm cột wallet_id (vì SQLite không hỗ trợ ADD CONSTRAINT NOT NULL
          // nếu đã có dữ liệu, ta tạo bảng tạm + copy)
          await db.execute('''
            CREATE TABLE coin_transactions_new (
              id TEXT PRIMARY KEY,
              user_id TEXT NOT NULL,
              wallet_id TEXT NOT NULL,
              amount INTEGER NOT NULL,
              coins_before INTEGER NOT NULL DEFAULT 0,
              coins_after INTEGER NOT NULL DEFAULT 0,
              type TEXT NOT NULL,
              description TEXT,
              payment_method TEXT,
              package_id TEXT,
              status TEXT NOT NULL,
              created_at TEXT NOT NULL,
              FOREIGN KEY (wallet_id) REFERENCES $tableWallets (id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            INSERT INTO coin_transactions_new
            SELECT id, user_id, wallet_id, amount, coins_before, coins_after,
                   type, description, payment_method, package_id, status, created_at
            FROM $tableCoinTransactions
          ''');
          await db.execute('DROP TABLE $tableCoinTransactions');
          await db.execute('ALTER TABLE coin_transactions_new RENAME TO $tableCoinTransactions');
        }
      } catch (e) {
        debugPrint('Migration v3->v4 warning: $e');
        // Nếu migration fail, xóa transactions cũ để tránh crash
        await db.delete(tableCoinTransactions);
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Tạo bảng Users
    await db.execute('''
      CREATE TABLE $tableUsers (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE NOT NULL,
        display_name TEXT NOT NULL,
        password TEXT NOT NULL,
        role TEXT NOT NULL,
        avatar_url TEXT
      )
    ''');

    // 2. Tạo bảng Mangas
    await db.execute('''
      CREATE TABLE $tableMangas (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        description TEXT,
        cover_url TEXT NOT NULL,
        genre TEXT NOT NULL,
        status TEXT NOT NULL,
        total_chapters INTEGER NOT NULL DEFAULT 0,
        current_chapter INTEGER NOT NULL DEFAULT 0,
        rating REAL NOT NULL DEFAULT 0.0,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        is_hidden INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await _createGenreTable(db);

    // 3. Tạo bảng Chapters
    await db.execute('''
      CREATE TABLE $tableChapters (
        id TEXT PRIMARY KEY,
        manga_id TEXT NOT NULL,
        chapter_number INTEGER NOT NULL,
        title TEXT NOT NULL,
        contents TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_locked INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        price REAL NOT NULL DEFAULT 0.0,
        FOREIGN KEY (manga_id) REFERENCES $tableMangas (id) ON DELETE CASCADE
      )
    ''');

    // 4. Tạo bảng User Purchased Chapters
    await db.execute('''
      CREATE TABLE $tableUserPurchasedChapters (
        user_id TEXT NOT NULL,
        chapter_id TEXT NOT NULL,
        purchased_at TEXT NOT NULL,
        PRIMARY KEY (user_id, chapter_id),
        FOREIGN KEY (user_id) REFERENCES $tableUsers (id) ON DELETE CASCADE,
        FOREIGN KEY (chapter_id) REFERENCES $tableChapters (id) ON DELETE CASCADE
      )
    ''');

    // 5. Tạo bảng Bookmarks
    await db.execute('''
      CREATE TABLE $tableBookmarks (
        user_id TEXT NOT NULL,
        manga_id TEXT NOT NULL,
        chapter_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        PRIMARY KEY (user_id, manga_id),
        FOREIGN KEY (user_id) REFERENCES $tableUsers (id) ON DELETE CASCADE,
        FOREIGN KEY (manga_id) REFERENCES $tableMangas (id) ON DELETE CASCADE,
        FOREIGN KEY (chapter_id) REFERENCES $tableChapters (id) ON DELETE CASCADE
      )
    ''');

    // 6. Tạo bảng coin (wallets, transactions, packages)
    await _createCoinTables(db);

    // 7. Nạp dữ liệu mẫu ban đầu
    await _seedInitialData(db);
    await _seedCoinPackages(db);
  }

  /// Tạo các bảng chapter/bookmark (idempotent)
  Future<void> _createChapterTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableChapters (
        id TEXT PRIMARY KEY,
        manga_id TEXT NOT NULL,
        chapter_number INTEGER NOT NULL,
        title TEXT NOT NULL,
        contents TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_locked INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        price REAL NOT NULL DEFAULT 0.0,
        FOREIGN KEY (manga_id) REFERENCES $tableMangas (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableUserPurchasedChapters (
        user_id TEXT NOT NULL,
        chapter_id TEXT NOT NULL,
        purchased_at TEXT NOT NULL,
        PRIMARY KEY (user_id, chapter_id),
        FOREIGN KEY (user_id) REFERENCES $tableUsers (id) ON DELETE CASCADE,
        FOREIGN KEY (chapter_id) REFERENCES $tableChapters (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableBookmarks (
        user_id TEXT NOT NULL,
        manga_id TEXT NOT NULL,
        chapter_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        PRIMARY KEY (user_id, manga_id),
        FOREIGN KEY (user_id) REFERENCES $tableUsers (id) ON DELETE CASCADE,
        FOREIGN KEY (manga_id) REFERENCES $tableMangas (id) ON DELETE CASCADE,
        FOREIGN KEY (chapter_id) REFERENCES $tableChapters (id) ON DELETE CASCADE
      )
    ''');
  }

  /// Tạo các bảng coin (idempotent, an toàn khi chạy lại)
  Future<void> _createCoinTables(Database db) async {
    // Bảng Wallets
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableWallets (
        id TEXT PRIMARY KEY,
        user_id TEXT UNIQUE NOT NULL,
        balance INTEGER NOT NULL DEFAULT 0,
        total_earned INTEGER NOT NULL DEFAULT 0,
        total_spent INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES $tableUsers (id) ON DELETE CASCADE
      )
    ''');

    // Bảng CoinTransactions
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableCoinTransactions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        wallet_id TEXT NOT NULL,
        amount INTEGER NOT NULL,
        coins_before INTEGER NOT NULL DEFAULT 0,
        coins_after INTEGER NOT NULL DEFAULT 0,
        type TEXT NOT NULL,
        description TEXT,
        payment_method TEXT,
        package_id TEXT,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (wallet_id) REFERENCES $tableWallets (id) ON DELETE CASCADE
      )
    ''');

    // Bảng CoinPackages
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableCoinPackages (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        coins INTEGER NOT NULL,
        price REAL NOT NULL,
        bonus_coins INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        is_featured INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
  Future<void> _createGenreTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableGenres (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');
    for (final name in const [
      'Action', 'Adventure', 'Fantasy', 'Comedy', 'Romance', 'Supernatural', 'Sports'
    ]) {
      await db.insert(
        tableGenres,
        {'id': name.toLowerCase(), 'name': name, 'created_at': DateTime.now().toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }
  Future<void> _seedInitialData(Database db) async {
    // Seed Users
    final seedUsers = [
      const AppUser(
        id: 'admin_1',
        username: 'admin',
        displayName: 'Quản Trị Viên (Admin)',
        password: 'admin123',
        role: UserRole.admin,
      ),
      const AppUser(
        id: 'staff_1',
        username: 'staff',
        displayName: 'Biên Tập Viên (Staff)',
        password: 'staff123',
        role: UserRole.staff,
      ),
      const AppUser(
        id: 'staff_phat',
        username: 'phatstaff',
        displayName: 'Nhân Viên Phát (Staff)',
        password: '123456',
        role: UserRole.staff,
      ),
      const AppUser(
        id: 'reader_1',
        username: 'reader',
        displayName: 'Độc Giả VIP (Reader)',
        password: 'reader123',
        role: UserRole.reader,
      ),
    ];

    for (final user in seedUsers) {
      await db.insert(
        tableUsers,
        user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // Seed Mangas
    final seedMangas = [
      Manga(
        id: '1',
        title: 'One Piece',
        author: 'Eiichiro Oda',
        description:
            'Monkey D. Luffy cùng băng Mũ Rơm giương buồm ra khơi để tìm kiếm kho báu huyền thoại One Piece và trở thành Vua Hải Tặc mới.',
        coverUrl:
            'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=600&auto=format&fit=crop&q=80',
        genre: 'Action',
        status: 'Ongoing',
        totalChapters: 1115,
        currentChapter: 1080,
        rating: 9.8,
        isFavorite: true,
      ),
      Manga(
        id: '2',
        title: 'Solo Leveling',
        author: 'Chugong',
        description:
            'Sung Jinwoo - thợ săn yếu nhất cấp E - bất ngờ nhận được hệ thống thăng cấp bí ẩn trong một hầm ngục kép nguy hiểm.',
        coverUrl:
            'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=600&auto=format&fit=crop&q=80',
        genre: 'Fantasy',
        status: 'Completed',
        totalChapters: 200,
        currentChapter: 200,
        rating: 9.6,
        isFavorite: true,
      ),
      Manga(
        id: '3',
        title: 'Frieren: Beyond Journey\'s End',
        author: 'Kanehito Yamada',
        description:
            'Chuyển hành trình của pháp sư Elf Frieren tìm hiểu về con người và cảm xúc sau khi tổ đội anh hùng đã đánh bại Ma Vương.',
        coverUrl:
            'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600&auto=format&fit=crop&q=80',
        genre: 'Adventure',
        status: 'Ongoing',
        totalChapters: 130,
        currentChapter: 95,
        rating: 9.7,
        isFavorite: false,
      ),
      Manga(
        id: '4',
        title: 'Jujutsu Kaisen',
        author: 'Gege Akutami',
        description:
            'Yuji Itadori nuốt ngón tay nguyền hồn Sukuna và bước chân vào thế giới Chú Thuật Sư đầy hiểm nguy để bảo vệ người vô tội.',
        coverUrl:
            'https://images.unsplash.com/photo-1618336753974-aae8e04506aa?w=600&auto=format&fit=crop&q=80',
        genre: 'Action',
        status: 'Completed',
        totalChapters: 271,
        currentChapter: 271,
        rating: 9.2,
        isFavorite: false,
      ),
      Manga(
        id: '5',
        title: 'Spy x Family',
        author: 'Tatsuya Endo',
        description:
            'Điệp viên Twilight phải lập gia đình giả nhằm thực hiện nhiệm vụ, mà không biết vợ là sát thủ và con gái có năng lực đọc suy nghĩ.',
        coverUrl:
            'https://images.unsplash.com/photo-1563089145-599997674d42?w=600&auto=format&fit=crop&q=80',
        genre: 'Comedy',
        status: 'Ongoing',
        totalChapters: 104,
        currentChapter: 75,
        rating: 9.4,
        isFavorite: true,
      ),
      Manga(
        id: '6',
        title: 'Blue Lock',
        author: 'Muneyuki Kaneshiro',
        description:
            'Dự án biệt lập tập hợp 300 tiền đạo trẻ xuất sắc nhất Nhật Bản nhằm tìm ra một chân sút ích kỷ và sắc bén nhất thế giới.',
        coverUrl:
            'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&auto=format&fit=crop&q=80',
        genre: 'Sports',
        status: 'Ongoing',
        totalChapters: 280,
        currentChapter: 240,
        rating: 9.1,
        isFavorite: false,
      ),
    ];

    for (final manga in seedMangas) {
      await db.insert(
        tableMangas,
        manga.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // Seed Chapters
    await _seedChaptersData(db);
  }

  Future<void> _seedChaptersData(Database db) async {
    final now = DateTime.now();
    final seedChapters = [
      Chapter(
        id: 'c1_1',
        mangaId: '1',
        chapterNumber: 1,
        title: 'Bình minh của cuộc phiêu lưu',
        contents: [
          'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=900&auto=format&fit=crop&q=80',
          'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=900&auto=format&fit=crop&q=80',
          'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=900&auto=format&fit=crop&q=80',
        ],
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 20)),
        isLocked: false,
        isDeleted: false,
        price: 0.0,
      ),
      Chapter(
        id: 'c1_2',
        mangaId: '1',
        chapterNumber: 2,
        title: 'Cậu bé Mũ Rơm Luffy',
        contents: [
          'https://images.unsplash.com/photo-1618336753974-aae8e04506aa?w=900&auto=format&fit=crop&q=80',
          'https://images.unsplash.com/photo-1563089145-599997674d42?w=900&auto=format&fit=crop&q=80',
        ],
        createdAt: now.subtract(const Duration(days: 15)),
        updatedAt: now.subtract(const Duration(days: 10)),
        isLocked: false,
        isDeleted: false,
        price: 0.0,
      ),
      Chapter(
        id: 'c1_3',
        mangaId: '1',
        chapterNumber: 3,
        title: 'Thợ săn hải tặc Roronoa Zoro (VIP)',
        contents: [
          'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=900&auto=format&fit=crop&q=80',
          'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=900&auto=format&fit=crop&q=80',
        ],
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now.subtract(const Duration(days: 2)),
        isLocked: true,
        isDeleted: false,
        price: 3000.0,
      ),
      Chapter(
        id: 'c2_1',
        mangaId: '2',
        chapterNumber: 1,
        title: 'Thợ săn yếu nhất cấp E',
        contents: [
          'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=900&auto=format&fit=crop&q=80',
          'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=900&auto=format&fit=crop&q=80',
        ],
        createdAt: now.subtract(const Duration(days: 25)),
        updatedAt: now.subtract(const Duration(days: 18)),
        isLocked: false,
        isDeleted: false,
        price: 0.0,
      ),
      Chapter(
        id: 'c2_2',
        mangaId: '2',
        chapterNumber: 2,
        title: 'Hầm ngục kép nguy hiểm',
        contents: [
          'https://images.unsplash.com/photo-1618336753974-aae8e04506aa?w=900&auto=format&fit=crop&q=80',
        ],
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 5)),
        isLocked: true,
        isDeleted: false,
        price: 5000.0,
      ),
    ];

    for (final chapter in seedChapters) {
      await db.insert(
        tableChapters,
        chapter.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _seedCoinPackages(Database db) async {
    final now = DateTime.now().toIso8601String();
    final packages = [
      {
        'id': 'pkg_1', 'name': 'Starter Pack', 'coins': 100, 'price': 10000.0,
        'bonus_coins': 0, 'is_active': 1, 'is_featured': 0, 'sort_order': 1, 'created_at': now
      },
      {
        'id': 'pkg_2', 'name': 'Bronze Pack', 'coins': 500, 'price': 45000.0,
        'bonus_coins': 50, 'is_active': 1, 'is_featured': 0, 'sort_order': 2, 'created_at': now
      },
      {
        'id': 'pkg_3', 'name': 'Silver Pack', 'coins': 1000, 'price': 85000.0,
        'bonus_coins': 150, 'is_active': 1, 'is_featured': 0, 'sort_order': 3, 'created_at': now
      },
      {
        'id': 'pkg_4', 'name': 'Gold Pack', 'coins': 2000, 'price': 160000.0,
        'bonus_coins': 400, 'is_active': 1, 'is_featured': 1, 'sort_order': 4, 'created_at': now
      },
      {
        'id': 'pkg_5', 'name': 'VIP Pack', 'coins': 5000, 'price': 380000.0,
        'bonus_coins': 1250, 'is_active': 1, 'is_featured': 1, 'sort_order': 5, 'created_at': now
      },
    ];

    for (final pkg in packages) {
      await db.insert(
        tableCoinPackages,
        pkg,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // ===================== CRUD MANGA =====================

  Future<List<Manga>> getAllMangas() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableMangas);
    return maps.map((map) => Manga.fromMap(map)).toList();
  }

  Future<List<Map<String, dynamic>>> getAllGenres() async {
    final db = await database;
    return db.query(tableGenres, orderBy: 'name COLLATE NOCASE ASC');
  }

  Future<int> insertGenre(String id, String name) async {
    final db = await database;
    return db.insert(tableGenres, {
      'id': id,
      'name': name.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> renameGenre(String id, String oldName, String newName) async {
    final db = await database;
    return db.transaction((txn) async {
      final count = await txn.update(tableGenres, {'name': newName.trim()}, where: 'id = ?', whereArgs: [id]);
      await txn.update(tableMangas, {'genre': newName.trim()}, where: 'genre = ?', whereArgs: [oldName]);
      return count;
    });
  }

  Future<int> deleteGenre(String id, String name) async {
    final db = await database;
    final countRows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM $tableMangas WHERE genre = ?', [name],
    );
    final linked = (countRows.first['count'] as num?)?.toInt() ?? 0;
    if (linked > 0) throw StateError('Thể loại đang được $linked truyện sử dụng. Hãy đổi thể loại truyện trước khi xóa.');
    return db.delete(tableGenres, where: 'id = ?', whereArgs: [id]);
  }

  /// Lấy chi tiết truyện theo ID
  Future<Manga?> getMangaById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableMangas,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Manga.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertManga(Manga manga) async {
    final db = await database;
    return await db.insert(
      tableMangas,
      manga.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateManga(Manga manga) async {
    final db = await database;
    return await db.update(
      tableMangas,
      manga.toMap(),
      where: 'id = ?',
      whereArgs: [manga.id],
    );
  }

  Future<int> deleteManga(String id) async {
    final db = await database;
    return await db.delete(
      tableMangas,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateFavorite(String id, bool isFavorite) async {
    final db = await database;
    return await db.update(
      tableMangas,
      {'is_favorite': isFavorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> setMangaHidden(String id, bool hidden) async {
    final db = await database;
    return db.update(tableMangas, {'is_hidden': hidden ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  /// Cập nhật tiến độ đọc chapter
  Future<int> updateChapter(String id, int currentChapter) async {
    final db = await database;
    return await db.update(
      tableMangas,
      {'current_chapter': currentChapter},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ===================== CRUD USER =====================

  Future<List<AppUser>> getAllUsers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableUsers);
    return maps.map((map) => AppUser.fromMap(map)).toList();
  }

  Future<AppUser?> getUserByUsername(String username) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableUsers,
      where: 'LOWER(username) = ?',
      whereArgs: [username.trim().toLowerCase()],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return AppUser.fromMap(maps.first);
    }
    return null;
  }

  Future<AppUser?> getUserById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableUsers,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return AppUser.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertUser(AppUser user) async {
    final db = await database;
    return await db.insert(
      tableUsers,
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> updateUserRole(String id, UserRole role) async {
    final db = await database;
    return await db.update(
      tableUsers,
      {'role': role.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateUserPassword(String username, String newPassword) async {
    final db = await database;
    return await db.update(
      tableUsers,
      {'password': newPassword},
      where: 'LOWER(username) = ?',
      whereArgs: [username.trim().toLowerCase()],
    );
  }

  /// Xóa người dùng (chỉ Admin) — cascade sẽ xóa wallet/transaction
  Future<int> deleteUser(String id) async {
    final db = await database;
    return await db.delete(
      tableUsers,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> resetToDefault() async {
    final db = await database;
    await db.delete(tableUsers);
    await db.delete(tableMangas);
    await db.delete(tableChapters);
    await db.delete(tableUserPurchasedChapters);
    await db.delete(tableBookmarks);
    await db.delete(tableWallets);
    await db.delete(tableCoinTransactions);
    await db.delete(tableCoinPackages);
    await _seedInitialData(db);
    await _seedCoinPackages(db);
  }

  /// Xóa cache database cũ (dùng khi schema thay đổi trên web)
  /// Gọi 1 lần rồi reload app
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete(tableCoinTransactions);
    await db.delete(tableWallets);
    await db.delete(tableUsers);
    await db.delete(tableMangas);
    await db.delete(tableChapters);
    await db.delete(tableUserPurchasedChapters);
    await db.delete(tableBookmarks);
    await db.delete(tableCoinPackages);
    // Seed lại dữ liệu mặc định
    await _seedInitialData(db);
    await _seedCoinPackages(db);
  }

  // ===================== CRUD CHAPTER =====================

  Future<List<Chapter>> getChaptersByMangaId(
    String mangaId, {
    bool includeDeleted = false,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableChapters,
      where: includeDeleted
          ? 'manga_id = ?'
          : 'manga_id = ? AND is_deleted = 0',
      whereArgs: [mangaId],
      orderBy: 'chapter_number ASC',
    );
    return maps.map((map) => Chapter.fromMap(map)).toList();
  }

  Future<Chapter?> getChapterById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableChapters,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Chapter.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertChapter(Chapter chapter) async {
    final db = await database;
    return await db.insert(
      tableChapters,
      chapter.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateChapterData(Chapter chapter) async {
    final db = await database;
    return await db.update(
      tableChapters,
      chapter.toMap(),
      where: 'id = ?',
      whereArgs: [chapter.id],
    );
  }

  Future<int> softDeleteChapter(String id) async {
    final db = await database;
    return await db.update(
      tableChapters,
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteChapterPermanently(String id) async {
    final db = await database;
    return await db.delete(
      tableChapters,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> isChapterNumberTaken(String mangaId, int chapterNumber, {String? excludeChapterId}) async {
    final db = await database;
    final whereClause = excludeChapterId != null
        ? 'manga_id = ? AND chapter_number = ? AND id != ? AND is_deleted = 0'
        : 'manga_id = ? AND chapter_number = ? AND is_deleted = 0';
    final whereArgs = excludeChapterId != null
        ? [mangaId, chapterNumber, excludeChapterId]
        : [mangaId, chapterNumber];
    final maps = await db.query(
      tableChapters,
      columns: ['id'],
      where: whereClause,
      whereArgs: whereArgs,
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  // ===================== USER CHAPTER PURCHASES =====================

  Future<bool> isChapterPurchasedByUser(String userId, String chapterId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableUserPurchasedChapters,
      where: 'user_id = ? AND chapter_id = ?',
      whereArgs: [userId, chapterId],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  Future<Set<String>> getPurchasedChapterIds(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableUserPurchasedChapters,
      columns: ['chapter_id'],
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return maps.map((row) => row['chapter_id'] as String).toSet();
  }

  Future<void> purchaseChapter(String userId, String chapterId) async {
    final db = await database;
    await db.insert(
      tableUserPurchasedChapters,
      {
        'user_id': userId,
        'chapter_id': chapterId,
        'purchased_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ===================== BOOKMARKS =====================

  Future<Bookmark?> getBookmark(String userId, String mangaId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableBookmarks,
      where: 'user_id = ? AND manga_id = ?',
      whereArgs: [userId, mangaId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Bookmark.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertBookmark(Bookmark bookmark) async {
    final db = await database;
    return await db.insert(
      tableBookmarks,
      bookmark.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateBookmark(Bookmark bookmark) async {
    final db = await database;
    return await db.update(
      tableBookmarks,
      bookmark.toMap(),
      where: 'user_id = ? AND manga_id = ?',
      whereArgs: [bookmark.userId, bookmark.mangaId],
    );
  Future<List<BookmarkDetail>> getUserBookmarks(String userId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT b.user_id, b.manga_id, b.chapter_id, b.created_at,
             m.title AS manga_title, m.cover_url AS cover_url,
             c.title AS chapter_title, c.chapter_number AS chapter_number
      FROM $tableBookmarks b
      JOIN $tableMangas m ON m.id = b.manga_id
      JOIN $tableChapters c ON c.id = b.chapter_id
      WHERE b.user_id = ?
      ORDER BY b.created_at DESC
    ''', [userId]);
    return rows.map((row) => BookmarkDetail(
      bookmark: Bookmark.fromMap(row),
      mangaTitle: row['manga_title'] as String? ?? '',
      coverUrl: row['cover_url'] as String? ?? '',
      chapterTitle: row['chapter_title'] as String? ?? '',
      chapterNumber: (row['chapter_number'] as num?)?.toInt() ?? 0,
    )).toList();
  }

  Future<void> toggleBookmark(String userId, String mangaId, String chapterId) async {
    final db = await database;
    final existing = await db.query(
      tableBookmarks,
      columns: ['chapter_id'],
      where: 'user_id = ? AND manga_id = ?',
      whereArgs: [userId, mangaId],
      limit: 1,
    );
    if (existing.isNotEmpty && existing.first['chapter_id'] == chapterId) {
      await deleteBookmark(userId, mangaId);
      return;
    }
    await db.insert(tableBookmarks, {
      'user_id': userId,
      'manga_id': mangaId,
      'chapter_id': chapterId,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> deleteBookmark(String userId, String mangaId) async {
    final db = await database;
    return await db.delete(
    return db.delete(
      tableBookmarks,
      where: 'user_id = ? AND manga_id = ?',
      whereArgs: [userId, mangaId],
    );
  }

  /// Bật/tắt bookmark: nếu đã tồn tại thì xóa, ngược lại thì thêm
  Future<bool> toggleBookmark(String userId, String mangaId, String chapterId) async {
    final existing = await getBookmark(userId, mangaId);
    if (existing != null) {
      await deleteBookmark(userId, mangaId);
      return false;
    } else {
      final bookmark = Bookmark(
        userId: userId,
        mangaId: mangaId,
        chapterId: chapterId,
        createdAt: DateTime.now(),
      );
      await insertBookmark(bookmark);
      return true;
    }
  }

  /// Lấy toàn bộ bookmark của user (JOIN bảng mangas và chapters)
  Future<List<BookmarkDetail>> getUserBookmarks(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT
        b.user_id, b.manga_id, b.chapter_id, b.created_at,
        m.title as manga_title, m.cover_url,
        c.chapter_number, c.title as chapter_title
      FROM $tableBookmarks b
      INNER JOIN $tableMangas m ON b.manga_id = m.id
      INNER JOIN $tableChapters c ON b.chapter_id = c.id
      WHERE b.user_id = ?
      ORDER BY b.created_at DESC
    ''', [userId]);
    return maps.map((map) => BookmarkDetail.fromMap(map)).toList();
  }

  // ===================== CRUD WALLET =====================

  Future<Wallet?> getWalletByUserId(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableWallets,
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Wallet.fromMap(maps.first);
    }
    return null;
  Future<Wallet?> getWalletByUserId(String userId) async {
    final db = await database;
    final rows = await db.query(tableWallets, where: 'user_id = ?', whereArgs: [userId], limit: 1);
    return rows.isEmpty ? null : Wallet.fromMap(rows.first);
  }

  Future<int> insertWallet(Wallet wallet) async {
    final db = await database;
    return await db.insert(
      tableWallets,
      wallet.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateWalletBalance(
    String userId,
    int newBalance,
    int newTotalEarned,
    int newTotalSpent,
  ) async {
    final db = await database;
    return await db.update(
      tableWallets,
      {
        'balance': newBalance,
        'total_earned': newTotalEarned,
        'total_spent': newTotalSpent,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // ===================== CRUD COIN TRANSACTION =====================

  Future<List<CoinTransaction>> getTransactionsByUserId(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableCoinTransactions,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => CoinTransaction.fromMap(map)).toList();
  }

  Future<int> insertTransaction(CoinTransaction tx) async {
    final db = await database;
    return await db.insert(
      tableCoinTransactions,
      tx.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<CoinTransaction?> getTransactionById(String id) async {
    final db = await database;
    final maps = await db.query(
      tableCoinTransactions,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return CoinTransaction.fromMap(maps.first);
    return rows.map(CoinTransaction.fromMap).toList();
  }

  Future<int> insertTransaction(CoinTransaction transaction) async {
    final db = await database;
    return db.insert(tableTransactions, transaction.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateTransactionStatus(String id, TransactionStatus status) async {
    final db = await database;
    return await db.update(
      tableCoinTransactions,
      {'status': status.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ===================== CRUD COIN PACKAGE =====================

  /// Mirrors authenticated server receipts locally. The server ledger is the
  /// authority; duplicate snapshots never add coins a second time.
  Future<CoinTransaction> cacheServerPayment(String userId, PaymentOrder order) async {
    final db = await database;
    return db.transaction((txn) async {
      final now = DateTime.now();
      final wallets = await txn.query(tableWallets, where: 'user_id = ?', whereArgs: [userId]);
      final wallet = wallets.isEmpty
          ? Wallet(id: 'wallet_$userId', userId: userId, balance: 0, totalEarned: 0,
              totalSpent: 0, createdAt: now, updatedAt: now)
          : Wallet.fromMap(wallets.first);
      if (wallets.isEmpty) await txn.insert(tableWallets, wallet.toMap());
      final rows = await txn.query(tableCoinTransactions, where: 'id = ?', whereArgs: [order.id]);
      final existing = rows.isEmpty ? null : CoinTransaction.fromMap(rows.first);
      if (existing != null && existing.userId != userId) throw StateError('Payment belongs to another user.');
      if (existing?.status == TransactionStatus.completed) return existing!;
      final status = switch (order.status) {
        'completed' => TransactionStatus.completed,
        'expired' || 'failed' => TransactionStatus.failed,
        'cancelled' => TransactionStatus.cancelled,
        _ => TransactionStatus.pending,
      };
      final coins = order.package.totalCoins;
      final balanceAfter = status == TransactionStatus.completed ? wallet.balance + coins : wallet.balance;
      if (status == TransactionStatus.completed) {
        await txn.update(tableWallets, {
          'balance': balanceAfter, 'total_earned': wallet.totalEarned + coins,
          'updated_at': now.toIso8601String(),
        }, where: 'user_id = ?', whereArgs: [userId]);
      }
      final transaction = CoinTransaction(id: order.id, userId: userId, walletId: wallet.id,
        type: TransactionType.deposit, amount: coins, coinsBefore: wallet.balance,
        coinsAfter: balanceAfter, description: 'Nạp coins từ ${order.package.name} (${order.transferCode})',
        paymentMethod: 'Chuyển khoản ngân hàng', packageId: order.package.id,
        status: status, createdAt: order.paidAt ?? order.createdAt);
      if (existing == null) {
        await txn.insert(tableCoinTransactions, transaction.toMap());
      } else {
        await txn.update(tableCoinTransactions, transaction.toMap(), where: 'id = ?', whereArgs: [order.id]);
      }
      return transaction;
    });
    return db.update(tableTransactions, {'status': status.name}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<CoinPackage>> getAllCoinPackages({bool activeOnly = false}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableCoinPackages,
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'price ASC',
    );
    return maps.map((map) => CoinPackage.fromMap(map)).toList();
    final rows = await db.query(
      tableCoinPackages,
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'sort_order ASC, price ASC',
    );
    return rows.map(CoinPackage.fromMap).toList();
  }

  Future<CoinPackage?> getCoinPackageById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableCoinPackages,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return CoinPackage.fromMap(maps.first);
    }
    return null;
    final rows = await db.query(tableCoinPackages, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : CoinPackage.fromMap(rows.first);
  }

  Future<int> insertCoinPackage(CoinPackage pkg) async {
    final db = await database;
    return await db.insert(
      tableCoinPackages,
      pkg.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateCoinPackage(CoinPackage pkg) async {
    final db = await database;
    return await db.update(
      tableCoinPackages,
      pkg.toMap(),
      where: 'id = ?',
      whereArgs: [pkg.id],
    );
  }

  Future<int> deleteCoinPackage(String id) async {
    final db = await database;
    return await db.delete(
      tableCoinPackages,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  // ===================== CRUD DAILY CHECK-IN =====================

  /// Lấy thông tin thống kê điểm danh của user
  Future<UserCheckInStats?> getUserCheckInStats(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableUserCheckInStats,
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return UserCheckInStats.fromMap(maps.first);
    }
    return null;
  }

  /// Lưu/cập nhật thông tin thống kê điểm danh của user
  Future<int> saveUserCheckInStats(UserCheckInStats stats) async {
    final db = await database;
    return await db.insert(
      tableUserCheckInStats,
      stats.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Ghi nhận 1 lượt điểm danh vào lịch sử
  Future<int> insertCheckInHistory(DailyCheckInHistoryItem item) async {
    final db = await database;
    return await db.insert(
      tableDailyCheckInHistory,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Lấy danh sách lịch sử điểm danh của user
  Future<List<DailyCheckInHistoryItem>> getCheckInHistory(String userId, {int limit = 14}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableDailyCheckInHistory,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return maps.map((map) => DailyCheckInHistoryItem.fromMap(map)).toList();
  }
}
