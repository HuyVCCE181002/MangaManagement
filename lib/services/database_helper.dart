// Conditional imports: chọn factory theo nền tảng (web vs non-web)
import 'package:flutter/foundation.dart';
import 'database_factory_io.dart'
    if (dart.library.html) 'database_factory_web.dart';
import '../models/bookmark.dart';
import '../models/chapter.dart';
import '../models/manga.dart';
import '../models/user.dart';
import '../models/wallet.dart';
import '../models/coin_transaction.dart';
import '../models/coin_package.dart';
import '../models/daily_check_in.dart';
import '../models/payment_order.dart';
import '../models/notification_item.dart';
import '../models/admin_stats.dart';

class DatabaseHelper {
  static String _dbName = 'manga_vault.db';

  @visibleForTesting
  static void setDbNameForTesting(String name) {
    _dbName = name;
    _database = null;
  }

  // Lịch sử version:
  //   v1: users + mangas (bản đầu)
  //   v2: thêm chapters + user_purchased_chapters + bookmarks
  //   v3: thêm wallets + coin_transactions + coin_packages
  // v4: thêm wallet_id cho coin_transactions (sửa lỗi NOT NULL khi schema cache cũ)
  // v5: thêm is_active cho users (UC-42 vô hiệu hoá giữ lịch sử),
  //   payment_amount cho coin_transactions (UC-48 snapshot giá gói)
  static const int _dbVersion = 5;

  static const String tableUsers = 'users';
  static const String tableMangas = 'mangas';
  static const String tableGenres = 'genres';
  static const String tableChapters = 'chapters';
  static const String tableUserPurchasedChapters = 'user_purchased_chapters';
  static const String tableBookmarks = 'bookmarks';
  static const String tableWallets = 'wallets';
  static const String tableCoinTransactions = 'coin_transactions';
  static const String tableCoinPackages = 'coin_packages';
  static const String tableTransactions = tableCoinTransactions;
  static const String tableUserCheckInStats = 'user_check_in_stats';
  static const String tableDailyCheckInHistory = 'daily_check_in_history';
  static const String tableNotifications = 'notifications';

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
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    // Đảm bảo tài khoản Staff yêu cầu luôn sẵn sàng ngay cả trên DB đã tồn tại
    await _ensureRequiredAccounts(db);

    return db;
  }

  /// Thêm một cột vào bảng nếu cột đó chưa tồn tại.
  /// Dùng PRAGMA table_info để kiểm tra trước khi ALTER, tránh lỗi
  /// "duplicate column name" trên các bản cài đã có sẵn cột.
  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<void> _ensureRequiredAccounts(Database db) async {
    // Đảm bảo cột avatar_url luôn tồn tại trong bảng users
    await _addColumnIfMissing(db, tableUsers, 'avatar_url', 'TEXT');
    await _addColumnIfMissing(
      db,
      tableUsers,
      'is_active',
      'INTEGER NOT NULL DEFAULT 1',
    );
    await _addColumnIfMissing(
      db,
      tableCoinTransactions,
      'payment_amount',
      'INTEGER',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_coin_tx_user_created ON $tableCoinTransactions(user_id, created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchased_user ON $tableUserPurchasedChapters(user_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_coin_tx_type_status_created ON $tableCoinTransactions(type, status, created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchased_at ON $tableUserPurchasedChapters(purchased_at)',
    );

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
    await _addColumnIfMissing(
      db,
      tableCoinTransactions,
      'coins_before',
      'INTEGER DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      tableCoinTransactions,
      'coins_after',
      'INTEGER DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      tableCoinTransactions,
      'payment_method',
      'TEXT',
    );
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

    // Đảm bảo bảng notifications luôn tồn tại
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableNotifications (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        category TEXT NOT NULL,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        data TEXT,
        is_read INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    const phatStaff = AppUser(
      id: 'staff_phat',
      username: 'phatstaff',
      displayName: 'Nhân Viên Phát (Staff)',
      password: '123456',
      role: UserRole.staff,
    );
    final existing = await db.query(
      tableUsers,
      where: 'id = ?',
      whereArgs: [phatStaff.id],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert(
        tableUsers,
        phatStaff.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
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
      await _addColumnIfMissing(
        db,
        tableMangas,
        'is_hidden',
        'INTEGER NOT NULL DEFAULT 0',
      );
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
          await db.execute(
            'ALTER TABLE coin_transactions_new RENAME TO $tableCoinTransactions',
          );
        }
      } catch (e) {
        debugPrint('Migration v3->v4 warning: $e');
        // Nếu migration fail, xóa transactions cũ để tránh crash
        await db.delete(tableCoinTransactions);
      }
    }
    if (oldVersion < 5) {
      await _addColumnIfMissing(
        db,
        tableUsers,
        'is_active',
        'INTEGER NOT NULL DEFAULT 1',
      );
      await _addColumnIfMissing(
        db,
        tableCoinTransactions,
        'payment_amount',
        'INTEGER',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_coin_tx_user_created ON $tableCoinTransactions(user_id, created_at)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_purchased_user ON $tableUserPurchasedChapters(user_id)',
      );
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
        avatar_url TEXT,
        is_active INTEGER NOT NULL DEFAULT 1
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

    // Bảng notifications
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableNotifications (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        category TEXT NOT NULL,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        data TEXT,
        is_read INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
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
        payment_amount INTEGER,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (wallet_id) REFERENCES $tableWallets (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_coin_tx_user_created ON $tableCoinTransactions(user_id, created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchased_user ON $tableUserPurchasedChapters(user_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_coin_tx_type_status_created ON $tableCoinTransactions(type, status, created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchased_at ON $tableUserPurchasedChapters(purchased_at)',
    );

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
  }

  Future<void> _createGenreTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableGenres (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');
    for (final name in const [
      'Action',
      'Adventure',
      'Fantasy',
      'Comedy',
      'Romance',
      'Supernatural',
      'Sports',
    ]) {
      await db.insert(tableGenres, {
        'id': name.toLowerCase(),
        'name': name,
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
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
        'id': 'pkg_1',
        'name': 'Starter Pack',
        'coins': 100,
        'price': 10000.0,
        'bonus_coins': 0,
        'is_active': 1,
        'is_featured': 0,
        'sort_order': 1,
        'created_at': now,
      },
      {
        'id': 'pkg_2',
        'name': 'Bronze Pack',
        'coins': 500,
        'price': 45000.0,
        'bonus_coins': 50,
        'is_active': 1,
        'is_featured': 0,
        'sort_order': 2,
        'created_at': now,
      },
      {
        'id': 'pkg_3',
        'name': 'Silver Pack',
        'coins': 1000,
        'price': 85000.0,
        'bonus_coins': 150,
        'is_active': 1,
        'is_featured': 0,
        'sort_order': 3,
        'created_at': now,
      },
      {
        'id': 'pkg_4',
        'name': 'Gold Pack',
        'coins': 2000,
        'price': 160000.0,
        'bonus_coins': 400,
        'is_active': 1,
        'is_featured': 1,
        'sort_order': 4,
        'created_at': now,
      },
      {
        'id': 'pkg_5',
        'name': 'VIP Pack',
        'coins': 5000,
        'price': 380000.0,
        'bonus_coins': 1250,
        'is_active': 1,
        'is_featured': 1,
        'sort_order': 5,
        'created_at': now,
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
      final count = await txn.update(
        tableGenres,
        {'name': newName.trim()},
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.update(
        tableMangas,
        {'genre': newName.trim()},
        where: 'genre = ?',
        whereArgs: [oldName],
      );
      return count;
    });
  }

  Future<int> deleteGenre(String id, String name) async {
    final db = await database;
    final countRows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM $tableMangas WHERE genre = ?',
      [name],
    );
    final linked = (countRows.first['count'] as num?)?.toInt() ?? 0;
    if (linked > 0) {
      throw StateError(
        'Thể loại đang được $linked truyện sử dụng. Hãy đổi thể loại truyện trước khi xóa.',
      );
    }
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
    return await db.delete(tableMangas, where: 'id = ?', whereArgs: [id]);
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
    return db.update(
      tableMangas,
      {'is_hidden': hidden ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
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

  /// Cập nhật thông tin profile người dùng (Tên hiển thị & Avatar)
  Future<int> updateUserProfile({
    required String id,
    required String displayName,
    String? avatarUrl,
  }) async {
    final db = await database;
    final Map<String, dynamic> values = {'display_name': displayName};
    if (avatarUrl != null) {
      values['avatar_url'] = avatarUrl;
    }
    return await db.update(
      tableUsers,
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Cập nhật riêng avatar người dùng
  Future<int> updateUserAvatar(String id, String? avatarUrl) async {
    final db = await database;
    return await db.update(
      tableUsers,
      {'avatar_url': avatarUrl},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Vô hiệu hoá người dùng (UC-42): giữ ví, giao dịch, lịch sử mua.
  Future<int> deactivateUser(String id) async {
    final db = await database;
    return await db.update(
      tableUsers,
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> reactivateUser(String id) async {
    final db = await database;
    return await db.update(
      tableUsers,
      {'is_active': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Xóa người dùng (chỉ Admin) — cascade sẽ xóa wallet/transaction
  Future<int> deleteUser(String id) async {
    final db = await database;
    return await db.delete(tableUsers, where: 'id = ?', whereArgs: [id]);
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
    try {
      await db.delete(tableNotifications);
    } catch (_) {}
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
      {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteChapterPermanently(String id) async {
    final db = await database;
    return await db.delete(tableChapters, where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> isChapterNumberTaken(
    String mangaId,
    int chapterNumber, {
    String? excludeChapterId,
  }) async {
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
    await db.insert(tableUserPurchasedChapters, {
      'user_id': userId,
      'chapter_id': chapterId,
      'purchased_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
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
  }

  Future<void> toggleBookmark(
    String userId,
    String mangaId,
    String chapterId,
  ) async {
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
      tableBookmarks,
      where: 'user_id = ? AND manga_id = ?',
      whereArgs: [userId, mangaId],
    );
  }

  /// Lấy toàn bộ bookmark của user (JOIN bảng mangas và chapters)
  Future<List<BookmarkDetail>> getUserBookmarks(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT
        b.user_id, b.manga_id, b.chapter_id, b.created_at,
        m.title as manga_title, m.cover_url,
        c.chapter_number, c.title as chapter_title
      FROM $tableBookmarks b
      INNER JOIN $tableMangas m ON b.manga_id = m.id
      INNER JOIN $tableChapters c ON b.chapter_id = c.id
      WHERE b.user_id = ?
      ORDER BY b.created_at DESC
    ''',
      [userId],
    );
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
  }

  Future<int> insertWallet(Wallet wallet) async {
    final db = await database;
    return await db.insert(
      tableWallets,
      wallet.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Khôi phục ví + lịch sử đã chốt. Không cộng xu lần hai: ghi đè theo id.
  Future<void> restoreWalletSnapshot({
    required Wallet wallet,
    required List<CoinTransaction> transactions,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        tableWallets,
        wallet.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (final tx in transactions) {
        await txn.insert(
          tableCoinTransactions,
          tx.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
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

  Future<List<CoinTransaction>> getTransactionsByUserId(
    String userId, {
    int? limit,
    int offset = 0,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableCoinTransactions,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
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
  }

  Future<int> updateTransactionStatus(
    String id,
    TransactionStatus status,
  ) async {
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
  Future<CoinTransaction> cacheServerPayment(
    String userId,
    PaymentOrder order,
  ) async {
    final db = await database;
    return db.transaction((txn) async {
      final now = DateTime.now();
      final wallets = await txn.query(
        tableWallets,
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      final wallet = wallets.isEmpty
          ? Wallet(
              id: 'wallet_$userId',
              userId: userId,
              balance: 0,
              totalEarned: 0,
              totalSpent: 0,
              createdAt: now,
              updatedAt: now,
            )
          : Wallet.fromMap(wallets.first);
      if (wallets.isEmpty) await txn.insert(tableWallets, wallet.toMap());
      final rows = await txn.query(
        tableCoinTransactions,
        where: 'id = ?',
        whereArgs: [order.id],
      );
      final existing = rows.isEmpty
          ? null
          : CoinTransaction.fromMap(rows.first);
      if (existing != null && existing.userId != userId) {
        throw StateError('Payment belongs to another user.');
      }
      if (existing?.status == TransactionStatus.completed) return existing!;
      final status = switch (order.status) {
        'completed' => TransactionStatus.completed,
        'expired' || 'failed' => TransactionStatus.failed,
        'cancelled' => TransactionStatus.cancelled,
        _ => TransactionStatus.pending,
      };
      final coins = order.package.totalCoins;
      final balanceAfter = status == TransactionStatus.completed
          ? wallet.balance + coins
          : wallet.balance;
      if (status == TransactionStatus.completed) {
        await txn.update(
          tableWallets,
          {
            'balance': balanceAfter,
            'total_earned': wallet.totalEarned + coins,
            'updated_at': now.toIso8601String(),
          },
          where: 'user_id = ?',
          whereArgs: [userId],
        );
      }
      final transaction = CoinTransaction(
        id: order.id,
        userId: userId,
        walletId: wallet.id,
        type: TransactionType.deposit,
        amount: coins,
        coinsBefore: wallet.balance,
        coinsAfter: balanceAfter,
        description:
            'Nạp coins từ ${order.package.name} (${order.transferCode})',
        paymentMethod: 'Chuyển khoản ngân hàng',
        packageId: order.package.id,
        paymentAmount: order.amount,
        status: status,
        createdAt: order.paidAt ?? order.createdAt,
      );
      if (existing == null) {
        await txn.insert(tableCoinTransactions, transaction.toMap());
      } else {
        await txn.update(
          tableCoinTransactions,
          transaction.toMap(),
          where: 'id = ?',
          whereArgs: [order.id],
        );
      }
      return transaction;
    });
  }

  Future<List<CoinPackage>> getAllCoinPackages({
    bool activeOnly = false,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableCoinPackages,
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'sort_order ASC, price ASC',
    );
    return maps.map((map) => CoinPackage.fromMap(map)).toList();
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
    return await db.delete(tableCoinPackages, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> countTransactionsByPackage(String packageId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as c FROM $tableCoinTransactions WHERE package_id = ?',
      [packageId],
    );
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<int> countActiveAdmins() async {
    final db = await database;
    final rows = await db.rawQuery(
      "SELECT COUNT(*) as c FROM $tableUsers WHERE role = 'admin' AND IFNULL(is_active, 1) = 1",
    );
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  /// UC-45 fallback: hoàn tất nạp xu local khi payment server tắt.
  /// Idempotent — completed rồi thì trả về giao dịch cũ, không cộng xu lần 2.
  Future<CoinTransaction> completeLocalDeposit(String transactionId) async {
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        tableCoinTransactions,
        where: 'id = ?',
        whereArgs: [transactionId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Không tìm thấy giao dịch nạp.');
      }
      final existing = CoinTransaction.fromMap(rows.first);
      if (existing.type != TransactionType.deposit) {
        throw StateError('Giao dịch không phải nạp xu.');
      }
      if (existing.status == TransactionStatus.completed) return existing;
      if (existing.status != TransactionStatus.pending) {
        throw StateError('Giao dịch nạp không còn ở trạng thái chờ.');
      }

      final wallets = await txn.query(
        tableWallets,
        where: 'user_id = ?',
        whereArgs: [existing.userId],
        limit: 1,
      );
      if (wallets.isEmpty) {
        throw StateError('Không tìm thấy ví của người dùng.');
      }
      final wallet = Wallet.fromMap(wallets.first);
      final coins = existing.amount;
      final now = DateTime.now();
      final balanceAfter = wallet.balance + coins;
      await txn.update(
        tableWallets,
        {
          'balance': balanceAfter,
          'total_earned': wallet.totalEarned + coins,
          'updated_at': now.toIso8601String(),
        },
        where: 'user_id = ?',
        whereArgs: [existing.userId],
      );
      final completed = existing.copyWith(
        coinsBefore: wallet.balance,
        coinsAfter: balanceAfter,
        status: TransactionStatus.completed,
        description: existing.description.replaceFirst(
          'Chờ xác minh nạp',
          'Nạp (xác nhận local)',
        ),
      );
      await txn.update(
        tableCoinTransactions,
        completed.toMap(),
        where: 'id = ? AND status = ?',
        whereArgs: [transactionId, TransactionStatus.pending.name],
      );
      return completed;
    });
  }

  /// Mở khóa chương trong một transaction: trừ xu + ghi quyền sở hữu.
  Future<({bool success, String message, bool alreadyOwned})> unlockChapter({
    required String userId,
    required String chapterId,
  }) async {
    final db = await database;
    try {
      return await db.transaction((txn) async {
        final chapterRows = await txn.query(
          tableChapters,
          where: 'id = ?',
          whereArgs: [chapterId],
          limit: 1,
        );
        if (chapterRows.isEmpty) {
          return (
            success: false,
            message: 'Không tìm thấy chương.',
            alreadyOwned: false,
          );
        }
        final chapter = Chapter.fromMap(chapterRows.first);
        if (chapter.isDeleted) {
          return (
            success: false,
            message: 'Chương này đã bị xóa.',
            alreadyOwned: false,
          );
        }

        final owned = await txn.query(
          tableUserPurchasedChapters,
          where: 'user_id = ? AND chapter_id = ?',
          whereArgs: [userId, chapterId],
          limit: 1,
        );
        if (owned.isNotEmpty) {
          return (
            success: true,
            message: 'Bạn đã sở hữu chương này.',
            alreadyOwned: true,
          );
        }

        final requiredCoins = chapter.price.round();
        final now = DateTime.now();

        if (!chapter.isLocked || requiredCoins <= 0) {
          await txn.insert(tableUserPurchasedChapters, {
            'user_id': userId,
            'chapter_id': chapterId,
            'purchased_at': now.toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          return (
            success: true,
            message: 'Chương miễn phí đã được mở.',
            alreadyOwned: false,
          );
        }

        final wallets = await txn.query(
          tableWallets,
          where: 'user_id = ?',
          whereArgs: [userId],
          limit: 1,
        );
        if (wallets.isEmpty) {
          return (
            success: false,
            message: 'Không tìm thấy ví của người dùng.',
            alreadyOwned: false,
          );
        }
        final wallet = Wallet.fromMap(wallets.first);
        if (wallet.balance < requiredCoins) {
          return (
            success: false,
            message:
                'Số dư không đủ. Cần $requiredCoins coins, hiện có ${wallet.balance} coins.',
            alreadyOwned: false,
          );
        }

        final txId = 'unlock_${userId}_$chapterId';
        final existingTx = await txn.query(
          tableCoinTransactions,
          where: 'id = ?',
          whereArgs: [txId],
          limit: 1,
        );
        if (existingTx.isNotEmpty) {
          await txn.insert(tableUserPurchasedChapters, {
            'user_id': userId,
            'chapter_id': chapterId,
            'purchased_at': now.toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          return (
            success: true,
            message: 'Bạn đã sở hữu chương này.',
            alreadyOwned: true,
          );
        }

        final newBalance = wallet.balance - requiredCoins;
        final updated = await txn.update(
          tableWallets,
          {
            'balance': newBalance,
            'total_spent': wallet.totalSpent + requiredCoins,
            'updated_at': now.toIso8601String(),
          },
          where: 'user_id = ? AND balance >= ?',
          whereArgs: [userId, requiredCoins],
        );
        if (updated == 0) {
          return (
            success: false,
            message: 'Số dư không đủ để mở khóa chương.',
            alreadyOwned: false,
          );
        }

        await txn.insert(
          tableCoinTransactions,
          CoinTransaction(
            id: txId,
            userId: userId,
            walletId: wallet.id,
            type: TransactionType.purchase,
            amount: -requiredCoins,
            coinsBefore: wallet.balance,
            coinsAfter: newBalance,
            description:
                'Mua Chương ${chapter.chapterNumber}: ${chapter.title}',
            status: TransactionStatus.completed,
            createdAt: now,
          ).toMap(),
        );
        await txn.insert(tableUserPurchasedChapters, {
          'user_id': userId,
          'chapter_id': chapterId,
          'purchased_at': now.toIso8601String(),
        });
        return (
          success: true,
          message:
              'Đã mở khóa Chương ${chapter.chapterNumber}. Số dư: $newBalance',
          alreadyOwned: false,
        );
      });
    } catch (e) {
      debugPrint('unlockChapter failed: $e');
      return (
        success: false,
        message: 'Không thể mở khóa chương. Vui lòng thử lại.',
        alreadyOwned: false,
      );
    }
  }

  Future<AdminDashboardStats> getAdminDashboardStats({
    DateTime? since,
    DateTime? until,
  }) async {
    final db = await database;
    Future<int> count(String sql, [List<Object?> args = const []]) async {
      final rows = await db.rawQuery(sql, args);
      return (rows.first['c'] as num?)?.toInt() ?? 0;
    }

    final totalUsers = await count('SELECT COUNT(*) as c FROM $tableUsers');
    final activeUsers = await count(
      'SELECT COUNT(*) as c FROM $tableUsers WHERE IFNULL(is_active, 1) = 1',
    );
    final deactivatedUsers = totalUsers - activeUsers;
    final adminCount = await count(
      "SELECT COUNT(*) as c FROM $tableUsers WHERE role = 'admin' AND IFNULL(is_active, 1) = 1",
    );
    final staffCount = await count(
      "SELECT COUNT(*) as c FROM $tableUsers WHERE role = 'staff' AND IFNULL(is_active, 1) = 1",
    );
    final readerCount = await count(
      "SELECT COUNT(*) as c FROM $tableUsers WHERE role = 'reader' AND IFNULL(is_active, 1) = 1",
    );

    final totalMangas = await count('SELECT COUNT(*) as c FROM $tableMangas');
    final hiddenMangas = await count(
      'SELECT COUNT(*) as c FROM $tableMangas WHERE IFNULL(is_hidden, 0) = 1',
    );
    final totalChapters = await count(
      'SELECT COUNT(*) as c FROM $tableChapters WHERE is_deleted = 0',
    );
    final lockedChapters = await count(
      'SELECT COUNT(*) as c FROM $tableChapters WHERE is_deleted = 0 AND is_locked = 1 AND price > 0',
    );
    final totalGenres = await count('SELECT COUNT(*) as c FROM $tableGenres');

    final walletRows = await db.rawQuery(
      'SELECT IFNULL(SUM(balance), 0) as bal, IFNULL(SUM(total_earned), 0) as earned, IFNULL(SUM(total_spent), 0) as spent FROM $tableWallets',
    );
    final walletBalance = (walletRows.first['bal'] as num?)?.toInt() ?? 0;
    final totalEarned = (walletRows.first['earned'] as num?)?.toInt() ?? 0;
    final totalSpent = (walletRows.first['spent'] as num?)?.toInt() ?? 0;

    final range = _txRange(since, until);
    Future<Map<String, Object?>> depositAgg(String extra, List<Object> args) {
      return db
          .rawQuery(
            "SELECT COUNT(*) as c, IFNULL(SUM(amount), 0) as coins, IFNULL(SUM(payment_amount), 0) as vnd "
            "FROM $tableCoinTransactions WHERE type = 'deposit' AND status = 'completed' $extra",
            args,
          )
          .then((rows) => rows.first);
    }

    final completedDeposits = await depositAgg(range.sql, range.args);
    final failedDeposits = await count(
      "SELECT COUNT(*) as c FROM $tableCoinTransactions WHERE type = 'deposit' AND status IN ('failed', 'cancelled') ${range.sql}",
      range.args,
    );
    final pendingDeposits = await count(
      "SELECT COUNT(*) as c FROM $tableCoinTransactions WHERE type = 'deposit' AND status = 'pending' ${range.sql}",
      range.args,
    );
    final unlocks = await db.rawQuery(
      "SELECT COUNT(*) as c, IFNULL(SUM(ABS(amount)), 0) as coins "
      "FROM $tableCoinTransactions WHERE type = 'purchase' AND status = 'completed' AND id LIKE 'unlock_%' ${range.sql}",
      range.args,
    );

    final depositCount = (completedDeposits['c'] as num?)?.toInt() ?? 0;
    final coinsCredited = (completedDeposits['coins'] as num?)?.toInt() ?? 0;
    final revenueVnd = (completedDeposits['vnd'] as num?)?.toInt() ?? 0;
    final unlockCount = (unlocks.first['c'] as num?)?.toInt() ?? 0;
    final coinsSpentOnUnlocks = (unlocks.first['coins'] as num?)?.toInt() ?? 0;

    final prevRange = _previousRange(since, until);
    var previousRevenueVnd = 0;
    var previousFailedDeposits = 0;
    if (prevRange != null) {
      final prevCompleted = await depositAgg(prevRange.sql, prevRange.args);
      previousRevenueVnd = (prevCompleted['vnd'] as num?)?.toInt() ?? 0;
      previousFailedDeposits = await count(
        "SELECT COUNT(*) as c FROM $tableCoinTransactions WHERE type = 'deposit' AND status IN ('failed', 'cancelled') ${prevRange.sql}",
        prevRange.args,
      );
    }

    final statusRows = await db.rawQuery(
      'SELECT status, COUNT(*) as c FROM $tableCoinTransactions WHERE 1=1 ${range.sql} GROUP BY status',
      range.args,
    );
    final transactionsByStatus = <String, int>{
      for (final row in statusRows)
        (row['status'] as String? ?? 'unknown'):
            (row['c'] as num?)?.toInt() ?? 0,
    };

    final roleRows = await db.rawQuery(
      'SELECT role, COUNT(*) as c FROM $tableUsers GROUP BY role',
    );
    final usersByRole = <String, int>{
      for (final row in roleRows)
        (row['role'] as String? ?? 'unknown'): (row['c'] as num?)?.toInt() ?? 0,
    };

    final genreRows = await db.rawQuery(
      'SELECT genre, COUNT(*) as c FROM $tableMangas GROUP BY genre ORDER BY c DESC',
    );
    final mangasByGenre = <String, int>{
      for (final row in genreRows)
        (row['genre'] as String? ?? 'Khác'): (row['c'] as num?)?.toInt() ?? 0,
    };

    final revenueByDay = await _dailyPoints(
      db,
      "SELECT substr(created_at, 1, 10) as day, IFNULL(SUM(payment_amount), 0) as vnd, COUNT(*) as c "
      "FROM $tableCoinTransactions WHERE type = 'deposit' AND status = 'completed' ${range.sql} "
      "GROUP BY day ORDER BY day",
      range.args,
      since: since,
      until: until,
      vndKey: 'vnd',
    );
    final unlockSpendByDay = await _dailyPoints(
      db,
      "SELECT substr(created_at, 1, 10) as day, IFNULL(SUM(ABS(amount)), 0) as coins, COUNT(*) as c "
      "FROM $tableCoinTransactions WHERE type = 'purchase' AND status = 'completed' AND id LIKE 'unlock_%' ${range.sql} "
      "GROUP BY day ORDER BY day",
      range.args,
      since: since,
      until: until,
      coinsKey: 'coins',
    );

    final topRows = await db.rawQuery(
      "SELECT c.id as chapter_id, c.title as chapter_title, c.chapter_number, c.manga_id, "
      "IFNULL(m.title, '') as manga_title, COUNT(p.user_id) as unlocks, "
      "IFNULL(SUM(ABS(t.amount)), 0) as coins "
      "FROM $tableUserPurchasedChapters p "
      "JOIN $tableChapters c ON c.id = p.chapter_id "
      "LEFT JOIN $tableMangas m ON m.id = c.manga_id "
      "LEFT JOIN $tableCoinTransactions t ON t.id = 'unlock_' || p.user_id || '_' || p.chapter_id "
      "AND t.type = 'purchase' AND t.status = 'completed' "
      "WHERE 1=1 ${_purchasedRange(since, until).sql} "
      "GROUP BY c.id ORDER BY unlocks DESC LIMIT 8",
      _purchasedRange(since, until).args,
    );
    final topUnlockedChapters = topRows
        .map(
          (row) => TopUnlockedChapter(
            chapterId: row['chapter_id'] as String? ?? '',
            chapterTitle: row['chapter_title'] as String? ?? '',
            chapterNumber: (row['chapter_number'] as num?)?.toInt() ?? 0,
            mangaId: row['manga_id'] as String? ?? '',
            mangaTitle: row['manga_title'] as String? ?? '',
            unlocks: (row['unlocks'] as num?)?.toInt() ?? 0,
            coinsSpent: (row['coins'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();

    final staleCutoff = DateTime.now()
        .subtract(const Duration(minutes: 60))
        .toIso8601String();
    final pendingStaleCount = await count(
      "SELECT COUNT(*) as c FROM $tableCoinTransactions WHERE type = 'deposit' AND status = 'pending' AND created_at <= ?",
      [staleCutoff],
    );
    final inactivePackageCount = await count(
      'SELECT COUNT(*) as c FROM $tableCoinPackages WHERE IFNULL(is_active, 1) = 0',
    );
    final invalidPremiumCount = await count(
      'SELECT COUNT(*) as c FROM $tableChapters WHERE is_deleted = 0 AND '
      '((is_locked = 1 AND price <= 0) OR (is_locked = 0 AND price > 0))',
    );

    final alerts = <DashboardAlert>[
      if (pendingStaleCount > 0)
        DashboardAlert(
          id: 'stale_pending',
          title: 'Nạp đang chờ quá hạn',
          detail:
              '$pendingStaleCount giao dịch pending đã tồn tại trên 60 phút (cửa sổ thanh toán ~10 phút).',
          target: 'stale_pending',
        ),
      if (since != null && failedDeposits > previousFailedDeposits)
        DashboardAlert(
          id: 'failed_up',
          title: 'Nạp thất bại tăng so với kỳ trước',
          detail:
              'Kỳ này $failedDeposits, kỳ trước $previousFailedDeposits (failed + cancelled).',
          target: 'failed',
        ),
      if (previousRevenueVnd > 0 && revenueVnd < previousRevenueVnd * 0.5)
        DashboardAlert(
          id: 'revenue_drop',
          title: 'Doanh thu giảm mạnh',
          detail:
              'Doanh thu đã xác nhận $revenueVnd đ, kỳ trước $previousRevenueVnd đ (giảm trên 50%).',
          target: 'deposits',
        ),
      if (inactivePackageCount > 0)
        DashboardAlert(
          id: 'inactive_packages',
          title: 'Gói xu đang tắt',
          detail: '$inactivePackageCount gói is_active = 0, không dùng để nạp.',
          target: 'packages',
        ),
      if (invalidPremiumCount > 0)
        DashboardAlert(
          id: 'invalid_premium',
          title: 'Chapter premium cấu hình lệch',
          detail:
              '$invalidPremiumCount chương: khóa nhưng giá ≤ 0, hoặc giá > 0 nhưng không khóa.',
          target: 'invalid_chapters',
        ),
    ];

    final recentMaps = await db.query(
      tableCoinTransactions,
      where: range.sql.isEmpty ? null : range.sql.replaceFirst(' AND ', ''),
      whereArgs: range.args.isEmpty ? null : range.args,
      orderBy: 'created_at DESC',
      limit: 10,
    );
    final recent = recentMaps.map(CoinTransaction.fromMap).toList();

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
      completedDeposits: depositCount,
      failedDeposits: failedDeposits,
      pendingDeposits: pendingDeposits,
      coinsCredited: coinsCredited,
      revenueVnd: revenueVnd,
      unlockCount: unlockCount,
      coinsSpentOnUnlocks: coinsSpentOnUnlocks,
      recentTransactions: recent,
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
    );
  }

  ({String sql, List<Object> args}) _txRange(DateTime? since, DateTime? until) {
    final parts = <String>[];
    final args = <Object>[];
    if (since != null) {
      parts.add('created_at >= ?');
      args.add(since.toIso8601String());
    }
    if (until != null) {
      parts.add('created_at < ?');
      args.add(until.toIso8601String());
    }
    return (
      sql: parts.isEmpty ? '' : ' AND ${parts.join(' AND ')}',
      args: args,
    );
  }

  ({String sql, List<Object> args}) _purchasedRange(
    DateTime? since,
    DateTime? until,
  ) {
    final parts = <String>[];
    final args = <Object>[];
    if (since != null) {
      parts.add('p.purchased_at >= ?');
      args.add(since.toIso8601String());
    }
    if (until != null) {
      parts.add('p.purchased_at < ?');
      args.add(until.toIso8601String());
    }
    return (
      sql: parts.isEmpty ? '' : ' AND ${parts.join(' AND ')}',
      args: args,
    );
  }

  ({String sql, List<Object> args})? _previousRange(
    DateTime? since,
    DateTime? until,
  ) {
    if (since == null) return null;
    final end = until ?? DateTime.now();
    final duration = end.difference(since);
    if (duration.inSeconds <= 0) return null;
    return _txRange(since.subtract(duration), since);
  }

  Future<List<DailyPoint>> _dailyPoints(
    dynamic db,
    String sql,
    List<Object> args, {
    DateTime? since,
    DateTime? until,
    String vndKey = 'vnd',
    String coinsKey = 'coins',
  }) async {
    final rows = await db.rawQuery(sql, args) as List<Map<String, Object?>>;
    final byDay = <String, DailyPoint>{
      for (final row in rows)
        (row['day'] as String? ?? ''): DailyPoint(
          day: row['day'] as String? ?? '',
          revenueVnd: (row[vndKey] as num?)?.toInt() ?? 0,
          coins: (row[coinsKey] as num?)?.toInt() ?? 0,
          count: (row['c'] as num?)?.toInt() ?? 0,
        ),
    };
    if (since == null) {
      return byDay.values.toList()..sort((a, b) => a.day.compareTo(b.day));
    }
    final end = until ?? DateTime.now();
    final points = <DailyPoint>[];
    var cursor = DateTime(since.year, since.month, since.day);
    final last = DateTime(end.year, end.month, end.day);
    while (!cursor.isAfter(last)) {
      final key =
          '${cursor.year.toString().padLeft(4, '0')}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}';
      points.add(byDay[key] ?? DailyPoint(day: key));
      cursor = cursor.add(const Duration(days: 1));
    }
    return points;
  }

  Future<List<CoinTransaction>> queryAdminTransactions({
    String? type,
    List<String>? statuses,
    DateTime? since,
    DateTime? until,
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object>[];
    if (type != null) {
      where.add('type = ?');
      args.add(type);
    }
    if (statuses != null && statuses.isNotEmpty) {
      where.add('status IN (${List.filled(statuses.length, '?').join(',')})');
      args.addAll(statuses);
    }
    if (since != null) {
      where.add('created_at >= ?');
      args.add(since.toIso8601String());
    }
    if (until != null) {
      where.add('created_at < ?');
      args.add(until.toIso8601String());
    }
    final maps = await db.query(
      tableCoinTransactions,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map(CoinTransaction.fromMap).toList();
  }

  Future<List<AppUser>> queryAdminUsers({
    bool? isActive,
    String? role,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object>[];
    if (isActive != null) {
      where.add('IFNULL(is_active, 1) = ?');
      args.add(isActive ? 1 : 0);
    }
    if (role != null) {
      where.add('role = ?');
      args.add(role);
    }
    final maps = await db.query(
      tableUsers,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'username COLLATE NOCASE',
      limit: limit,
      offset: offset,
    );
    return maps.map(AppUser.fromMap).toList();
  }

  Future<List<Manga>> queryAdminMangas({
    bool? hidden,
    String? genre,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object>[];
    if (hidden != null) {
      where.add('IFNULL(is_hidden, 0) = ?');
      args.add(hidden ? 1 : 0);
    }
    if (genre != null) {
      where.add('genre = ?');
      args.add(genre);
    }
    final maps = await db.query(
      tableMangas,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'title COLLATE NOCASE',
      limit: limit,
      offset: offset,
    );
    return maps.map(Manga.fromMap).toList();
  }

  Future<List<Chapter>> queryAdminChapters({
    bool invalidPremium = false,
    bool lockedOnly = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    final where = <String>['is_deleted = 0'];
    if (invalidPremium) {
      where.add(
        '((is_locked = 1 AND price <= 0) OR (is_locked = 0 AND price > 0))',
      );
    } else if (lockedOnly) {
      where.add('is_locked = 1 AND price > 0');
    }
    final maps = await db.query(
      tableChapters,
      where: where.join(' AND '),
      orderBy: 'manga_id, chapter_number',
      limit: limit,
      offset: offset,
    );
    return maps.map(Chapter.fromMap).toList();
  }

  Future<List<CoinPackage>> queryAdminPackages({
    bool? active,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    final maps = await db.query(
      tableCoinPackages,
      where: active == null ? null : 'IFNULL(is_active, 1) = ?',
      whereArgs: active == null ? null : [active ? 1 : 0],
      orderBy: 'sort_order ASC, price ASC',
      limit: limit,
      offset: offset,
    );
    return maps.map(CoinPackage.fromMap).toList();
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
  Future<List<DailyCheckInHistoryItem>> getCheckInHistory(
    String userId, {
    int limit = 14,
  }) async {
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

  // ===================== NOTIFICATIONS =====================

  /// Thêm hoặc ghi đè thông báo
  Future<int> insertNotification(NotificationItem item) async {
    final db = await database;
    return await db.insert(
      tableNotifications,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Lấy danh sách thông báo theo userId (hoặc broadcast user_id IS NULL)
  Future<List<NotificationItem>> getNotifications({
    String? userId,
    String? category,
    int limit = 100,
  }) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (userId != null && userId.isNotEmpty) {
      whereClause = '(user_id = ? OR user_id IS NULL)';
      whereArgs.add(userId);
    }

    if (category != null && category.isNotEmpty) {
      if (whereClause.isNotEmpty) {
        whereClause += ' AND category = ?';
      } else {
        whereClause = 'category = ?';
      }
      whereArgs.add(category);
    }

    final maps = await db.query(
      tableNotifications,
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return maps.map((map) => NotificationItem.fromMap(map)).toList();
  }

  /// Đếm số thông báo chưa đọc
  Future<int> getUnreadNotificationCount({String? userId}) async {
    final db = await database;
    String whereClause = 'is_read = 0';
    List<dynamic> whereArgs = [];

    if (userId != null && userId.isNotEmpty) {
      whereClause += ' AND (user_id = ? OR user_id IS NULL)';
      whereArgs.add(userId);
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableNotifications WHERE $whereClause',
      whereArgs,
    );

    if (result.isEmpty) return 0;
    return (result.first['count'] as num?)?.toInt() ?? 0;
  }

  /// Đánh dấu một thông báo là đã đọc
  Future<int> markNotificationAsRead(String id) async {
    final db = await database;
    return await db.update(
      tableNotifications,
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Đánh dấu tất cả thông báo là đã đọc
  Future<int> markAllNotificationsAsRead({String? userId}) async {
    final db = await database;
    if (userId != null && userId.isNotEmpty) {
      return await db.update(
        tableNotifications,
        {'is_read': 1},
        where: 'user_id = ? OR user_id IS NULL',
        whereArgs: [userId],
      );
    } else {
      return await db.update(tableNotifications, {'is_read': 1});
    }
  }

  /// Xóa một thông báo theo ID
  Future<int> deleteNotification(String id) async {
    final db = await database;
    return await db.delete(
      tableNotifications,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Xóa tất cả thông báo
  Future<int> clearAllNotifications({String? userId}) async {
    final db = await database;
    if (userId != null && userId.isNotEmpty) {
      return await db.delete(
        tableNotifications,
        where: 'user_id = ? OR user_id IS NULL',
        whereArgs: [userId],
      );
    } else {
      return await db.delete(tableNotifications);
    }
  }
}
