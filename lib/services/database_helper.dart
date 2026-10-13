// Database helper - cross-platform
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';

// Conditional imports based on platform
// Non-web uses dart:io + FFI; web uses sqflite_common_ffi_web (no dart:io)
import 'database_factory_io.dart' if (dart.library.html) 'database_factory_web.dart';

import '../models/manga.dart';
import '../models/user.dart';
import '../models/wallet.dart';
import '../models/coin_transaction.dart';
import '../models/coin_package.dart';

class DatabaseHelper {
  static const String _dbName = 'manga_vault.db';
  static const int _dbVersion = 3;

  static const String tableUsers = 'users';
  static const String tableMangas = 'mangas';
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

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migrate từ version 1 lên 2: thêm bảng coin
    if (oldVersion < 2) {
      await _createCoinTables(db);
      await _seedCoinPackages(db);
    }
    // Migrate từ version 2 lên 3: bảng coin có thể chưa tồn tại trên
    // các bản cài cũ do _onCreate trước đây không gọi _createCoinTables.
    if (oldVersion < 3) {
      await _createCoinTables(db);
      // _createCoinTables dùng IF NOT EXISTS, không thêm cột mới nếu bảng
      // đã có. Vì vậy ta phải ALTER TABLE thủ công cho từng cột còn thiếu
      // (bonus_coins, is_featured, sort_order) để tránh phải xóa DB.
      await _addColumnIfMissing(db, tableCoinPackages, 'bonus_coins',
          'INTEGER NOT NULL DEFAULT 0');
      await _addColumnIfMissing(db, tableCoinPackages, 'is_featured',
          'INTEGER NOT NULL DEFAULT 0');
      await _addColumnIfMissing(db, tableCoinPackages, 'sort_order',
          'INTEGER NOT NULL DEFAULT 0');
      await _seedCoinPackages(db);
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
        role TEXT NOT NULL
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
        is_favorite INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 3. Nạp dữ liệu mẫu ban đầu (Seed data)
    await _seedInitialData(db);

    // 4. Tạo bảng coin (wallets, transactions, packages) + seed gói coin
    // Lưu ý: bảng này được tạo ở cả _onCreate và _onUpgrade để đảm bảo
    // fresh install (đặc biệt trên web) cũng có đầy đủ schema.
    await _createCoinTables(db);
    await _seedCoinPackages(db);
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
  }

  // ===================== CRUD MANGA =====================

  /// Lấy toàn bộ danh sách truyện từ SQLite
  Future<List<Manga>> getAllMangas() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableMangas);
    return maps.map((map) => Manga.fromMap(map)).toList();
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

  /// Xóa người dùng (chỉ Admin)
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
    await _seedInitialData(db);
  }

  // ===================== COIN TABLES =====================

  Future<void> _createCoinTables(Database db) async {
    // Dùng IF NOT EXISTS để migration idempotent (an toàn khi chạy lại).
    // Tạo bảng Wallets
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableWallets (
        id TEXT PRIMARY KEY,
        user_id TEXT UNIQUE NOT NULL,
        balance INTEGER NOT NULL DEFAULT 0,
        total_earned INTEGER NOT NULL DEFAULT 0,
        total_spent INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES $tableUsers(id) ON DELETE CASCADE
      )
    ''');

    // Tạo bảng CoinTransactions
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableCoinTransactions (
        id TEXT PRIMARY KEY,
        wallet_id TEXT NOT NULL,
        amount INTEGER NOT NULL,
        type TEXT NOT NULL,
        description TEXT,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (wallet_id) REFERENCES $tableWallets(id) ON DELETE CASCADE
      )
    ''');

    // Tạo bảng CoinPackages
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableCoinPackages (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        coins INTEGER NOT NULL,
        price INTEGER NOT NULL,
        bonus_coins INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        is_featured INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _seedCoinPackages(Database db) async {
    final now = DateTime.now().toIso8601String();
    final packages = [
      {'id': 'pkg_1', 'name': 'Starter Pack', 'coins': 100, 'price': 10000.0, 'bonus_coins': 0, 'is_active': 1, 'is_featured': 0, 'sort_order': 1, 'created_at': now},
      {'id': 'pkg_2', 'name': 'Bronze Pack', 'coins': 500, 'price': 45000.0, 'bonus_coins': 50, 'is_active': 1, 'is_featured': 0, 'sort_order': 2, 'created_at': now},
      {'id': 'pkg_3', 'name': 'Silver Pack', 'coins': 1000, 'price': 85000.0, 'bonus_coins': 150, 'is_active': 1, 'is_featured': 0, 'sort_order': 3, 'created_at': now},
      {'id': 'pkg_4', 'name': 'Gold Pack', 'coins': 2000, 'price': 160000.0, 'bonus_coins': 400, 'is_active': 1, 'is_featured': 1, 'sort_order': 4, 'created_at': now},
      {'id': 'pkg_5', 'name': 'VIP Pack', 'coins': 5000, 'price': 380000.0, 'bonus_coins': 1250, 'is_active': 1, 'is_featured': 1, 'sort_order': 5, 'created_at': now},
    ];

    for (final pkg in packages) {
      await db.insert(
        tableCoinPackages,
        pkg,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
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
    final wallet = await getWalletByUserId(userId);
    if (wallet == null) return [];

    final List<Map<String, dynamic>> maps = await db.query(
      tableCoinTransactions,
      where: 'wallet_id = ?',
      whereArgs: [wallet.id],
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

  Future<List<CoinPackage>> getAllCoinPackages({bool activeOnly = false}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableCoinPackages,
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'price ASC',
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
    return await db.delete(
      tableCoinPackages,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
