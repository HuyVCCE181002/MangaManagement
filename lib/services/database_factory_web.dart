// Database factory stub for web platform
// Web hiện tại gặp vấn đề với sqflite_common_ffi_web + Chrome mới
// Tạm thời dùng stub factory

import 'package:sqflite_common/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

export 'package:sqflite_common/sqflite.dart' show Database, openDatabase, ConflictAlgorithm, Transaction;
export 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart' show createDatabaseFactoryFfiWeb;

Future<String> resolveDatabasePath(String dbName) async {
  return dbName;
}

void setupPlatformDatabase() {
  // Dùng noWebWorker: true để tránh service worker issues
  try {
    databaseFactory = createDatabaseFactoryFfiWeb(noWebWorker: true);
  } catch (e) {
    // Nếu fail, dùng mặc định (sẽ throw khi mở db)
    print('Warning: cannot init web database factory: $e');
  }
}
