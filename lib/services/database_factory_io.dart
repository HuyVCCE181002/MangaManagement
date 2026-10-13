// Database factory for non-web platforms (desktop, mobile)
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite_common/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

export 'package:sqflite_common/sqflite.dart' show Database, openDatabase, ConflictAlgorithm;
export 'package:sqflite_common_ffi/sqflite_ffi.dart' show databaseFactory, sqfliteFfiInit;

Future<String> resolveDatabasePath(String dbName) async {
  final dbPath = await getDatabasesPath();
  return join(dbPath, dbName);
}

void setupPlatformDatabase() {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  // Android/iOS: sử dụng default factory
}
