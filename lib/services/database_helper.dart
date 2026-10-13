import '../models/bookmark.dart';
import '../models/chapter.dart';
import '../models/manga.dart';
import '../models/user.dart';
import '../models/wallet.dart';
import '../models/coin_transaction.dart';
import '../models/coin_package.dart';
import 'database_factory_io.dart'
    if (dart.library.html) 'database_factory_web.dart';

class DatabaseHelper {
  static const String _dbName = 'manga_vault.db';
  static const int _dbVersion = 4;

  static const String tableUsers = 'users';
  static const String tableMangas = 'mangas';
  static const String tableGenres = 'genres';
  static const String tableChapters = 'chapters';
  static const String tableUserPurchasedChapters = 'user_purchased_chapters';
  static const String tableBookmarks = 'bookmarks';
  static const String tableWallets = 'wallets';
  static const String tableCoinTransactions = 'coin_transactions';
  static const String tableTransactions = tableCoinTransactions;
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
    if (oldVersion < 2) {
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
      await _seedChaptersData(db);
      await _createCoinTables(db);
      await _seedCoinPackages(db);
    }
    if (oldVersion < 3) {
      await _createCoinTables(db);
      await _addColumnIfMissing(db, tableCoinPackages, 'bonus_coins',
          'INTEGER NOT NULL DEFAULT 0');
      await _addColumnIfMissing(db, tableCoinPackages, 'is_featured',
          'INTEGER NOT NULL DEFAULT 0');
      await _addColumnIfMissing(db, tableCoinPackages, 'sort_order',
          'INTEGER NOT NULL DEFAULT 0');
      await _seedCoinPackages(db);
      await _createGenreTable(db);
    }
    if (oldVersion < 4) {
      await _createGenreTable(db);
      await _addColumnIfMissing(db, tableMangas, 'is_hidden', 'INTEGER NOT NULL DEFAULT 0');
    }
  }

  /// Thêm một cột vào bảng nếu cột đó chưa tồn tại.
  /// Dùng PRAGMA table_info để kiểm tra trước khi ALTER, tránh lỗi
  /// "duplicate column name" trên các bản cài đã có sẵn cột.
  Future<void> _addColumnIfMissing(
      Database db, String table, String column, String definition) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
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

    // 4. Tạo bảng User Purchased Chapters (Lịch sử mở khóa chương theo người dùng)
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

    // 6. Nạp dữ liệu mẫu ban đầu (Seed data)
    await _seedInitialData(db);

    // 7. Tạo bảng coin (wallets, transactions, packages) + seed gói coin
    await _createCoinTables(db);
    await _seedCoinPackages(db);
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
            'Chuyến hành trình của pháp sư Elf Frieren tìm hiểu về con người và cảm xúc sau khi tổ đội anh hùng đã đánh bại Ma Vương.',
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

  // ===================== CRUD MANGA =====================

  /// Lấy toàn bộ danh sách truyện từ SQLite
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

  /// Thêm truyện mới vào SQLite
  Future<int> insertManga(Manga manga) async {
    final db = await database;
    return await db.insert(
      tableMangas,
      manga.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Cập nhật thông tin truyện
  Future<int> updateManga(Manga manga) async {
    final db = await database;
    return await db.update(
      tableMangas,
      manga.toMap(),
      where: 'id = ?',
      whereArgs: [manga.id],
    );
  }

  /// Xóa truyện theo ID
  Future<int> deleteManga(String id) async {
    final db = await database;
    return await db.delete(
      tableMangas,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Cập nhật trạng thái yêu thích
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

  /// Lấy danh sách toàn bộ người dùng
  Future<List<AppUser>> getAllUsers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableUsers);
    return maps.map((map) => AppUser.fromMap(map)).toList();
  }

  /// Tìm user theo username
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

  /// Tìm user theo ID
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

  /// Thêm người dùng mới
  Future<int> insertUser(AppUser user) async {
    final db = await database;
    return await db.insert(
      tableUsers,
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Cập nhật vai trò người dùng (chỉ Admin)
  Future<int> updateUserRole(String id, UserRole role) async {
    final db = await database;
    return await db.update(
      tableUsers,
      {'role': role.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Cập nhật mật khẩu người dùng (cho Quên mật khẩu)
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
    final Map<String, dynamic> values = {
      'display_name': displayName,
    };
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

  /// Xóa người dùng (Admin hoặc User tự xóa)
  Future<int> deleteUser(String id) async {
    final db = await database;
    return await db.delete(
      tableUsers,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Khôi phục lại dữ liệu mặc định ban đầu
  Future<void> resetToDefault() async {
    final db = await database;
    await db.delete(tableUsers);
    await db.delete(tableMangas);
    await db.delete(tableChapters);
    await db.delete(tableUserPurchasedChapters);
    await _seedInitialData(db);
  }

  // ===================== CRUD CHAPTER =====================

  /// Lấy danh sách chapter của một truyện (mặc định chỉ lấy các chương chưa bị xóa mềm)
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

  /// Lấy thông tin chi tiết một chapter theo ID
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

  /// Thêm chapter mới vào SQLite
  Future<int> insertChapter(Chapter chapter) async {
    final db = await database;
    return await db.insert(
      tableChapters,
      chapter.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Cập nhật thông tin chapter trong SQLite
  Future<int> updateChapterData(Chapter chapter) async {
    final db = await database;
    return await db.update(
      tableChapters,
      chapter.toMap(),
      where: 'id = ?',
      whereArgs: [chapter.id],
    );
  }

  /// Xóa mềm chapter (soft delete: cập nhật is_deleted = 1)
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

  /// Xóa vĩnh viễn chapter khỏi SQLite
  Future<int> deleteChapterPermanently(String id) async {
    final db = await database;
    return await db.delete(
      tableChapters,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Kiểm tra số chương đã tồn tại trong manga chưa
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

  /// Kiểm tra xem người dùng đã mua chương này chưa
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

  /// Lấy tập hợp ID các chương mà người dùng đã mua
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

  /// Lưu giao dịch mua chương của người dùng
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

  /// Lấy bookmark hiện tại của user cho một truyện (nếu có)
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
    return db.delete(
      tableBookmarks,
      where: 'user_id = ? AND manga_id = ?',
      whereArgs: [userId, mangaId],
    );
  }

  Future<Wallet?> getWalletByUserId(String userId) async {
    final db = await database;
    final rows = await db.query(tableWallets, where: 'user_id = ?', whereArgs: [userId], limit: 1);
    return rows.isEmpty ? null : Wallet.fromMap(rows.first);
  }

  Future<int> insertWallet(Wallet wallet) async {
    final db = await database;
    return db.insert(tableWallets, wallet.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateWalletBalance(String userId, int balance, int totalEarned, int totalSpent) async {
    final db = await database;
    return db.update(tableWallets, {
      'balance': balance,
      'total_earned': totalEarned,
      'total_spent': totalSpent,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<List<CoinTransaction>> getTransactionsByUserId(String userId) async {
    final db = await database;
    final rows = await db.query(
      tableTransactions,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return rows.map(CoinTransaction.fromMap).toList();
  }

  Future<int> insertTransaction(CoinTransaction transaction) async {
    final db = await database;
    return db.insert(tableTransactions, transaction.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateTransactionStatus(String id, TransactionStatus status) async {
    final db = await database;
    return db.update(tableTransactions, {'status': status.name}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<CoinPackage>> getAllCoinPackages({required bool activeOnly}) async {
    final db = await database;
    final rows = await db.query(
      tableCoinPackages,
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'sort_order ASC, price ASC',
    );
    return rows.map(CoinPackage.fromMap).toList();
  }

  Future<CoinPackage?> getCoinPackageById(String id) async {
    final db = await database;
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
}
