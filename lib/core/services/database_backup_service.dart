import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/database/database_helper.dart';

/// Service to export / import the entire local SQLite database file.
///
/// **Export**: copies `al_sakr_local.db` out of the app-private directory
/// and shares it via the system share sheet (works on Android, iOS, Desktop).
///
/// **Import**: lets the user pick a `.db` file, closes the current connection,
/// overwrites the existing database, then re-opens it.
class DatabaseBackupService {
  // ── Export ──────────────────────────────────────────────────────────
  /// Shares the database file via the system share sheet.
  /// Returns `true` on success; throws on failure.
  Future<bool> exportDatabase() async {
    // On Android 10- we may need storage permission; on 11+ scoped storage
    // makes this unnecessary, but we request just in case.
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted && !status.isLimited) {
        throw Exception('لم يتم منح صلاحية الوصول إلى التخزين');
      }
    }

    final dbPath = await _getDatabasePath();
    final dbFile = File(dbPath);

    if (!await dbFile.exists()) {
      throw Exception('ملف قاعدة البيانات غير موجود');
    }

    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final exportName = 'al_sakr_backup_$timestamp.db';

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Desktop: Use FilePicker to save the file directly
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ نسخة احتياطية من الداتا بيز',
        fileName: exportName,
        type: FileType.custom,
        allowedExtensions: ['db'],
      );

      if (outputFile == null) return false;

      if (!outputFile.endsWith('.db')) {
        outputFile += '.db';
      }

      await dbFile.copy(outputFile);
      return true;
    } else {
      // Mobile: Copy to a temp location and share it
      final tempDir = await getTemporaryDirectory();
      final exportPath = p.join(tempDir.path, exportName);
      await dbFile.copy(exportPath);

      // Share via system sheet
      await Share.shareXFiles(
        [XFile(exportPath)],
        subject: 'Al Sakr Database Backup',
        text: 'نسخة احتياطية من قاعدة البيانات المحلية',
      );

      return true;
    }
  }

  // ── Import ──────────────────────────────────────────────────────────
  /// Opens a file picker for `.db` files, replaces the current database,
  /// and returns `true` on success.
  ///
  /// **WARNING**: this completely replaces all local data.
  Future<bool> importDatabase() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return false;

    final pickedPath = result.files.single.path;
    if (pickedPath == null) return false;

    final pickedFile = File(pickedPath);
    if (!await pickedFile.exists()) {
      throw Exception('الملف المختار غير موجود');
    }

    // Basic sanity check: file should end with .db
    if (!pickedPath.endsWith('.db')) {
      throw Exception('يرجى اختيار ملف بامتداد .db');
    }

    // Close the current database connection first.
    await DatabaseHelper().close();

    final dbPath = await _getDatabasePath();

    // Use sqflite deleteDatabase to properly clear WAL/SHM and cached processes
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Desktop doesn't always support deleteDatabase correctly without databaseFactory
      try {
        await databaseFactory.deleteDatabase(dbPath);
      } catch (_) {
        await deleteDatabase(dbPath); // Fallback
      }
    } else {
      await deleteDatabase(dbPath);
    }

    // Overwrite the existing database file.
    await pickedFile.copy(dbPath);

    // Force re-open by invalidating the singleton's cached instance.
    // The next call to `DatabaseHelper().database` will re-open the file.
    // We call it once here to trigger the re-open.
    await DatabaseHelper().database;

    return true;
  }

  // ── Clear ──────────────────────────────────────────────────────────
  /// Deletes the local database file, clearing all local data.
  Future<bool> clearDatabase() async {
    await DatabaseHelper().close();
    final dbPath = await _getDatabasePath();

    // Use sqflite deleteDatabase to properly clear WAL/SHM and cached processes
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        await databaseFactory.deleteDatabase(dbPath);
      } catch (_) {
        await deleteDatabase(dbPath); // Fallback
      }
    } else {
      await deleteDatabase(dbPath);
    }

    // Call it here to force recreating the tables if not immediately exiting
    await DatabaseHelper().database;
    return true;
  }

  // ── Helpers ─────────────────────────────────────────────────────────
  Future<String> _getDatabasePath() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    return p.join(documentsDir.path, DbConstants.databaseName);
  }

  /// Returns the size of the current database file in a human-readable string.
  Future<String> getDatabaseSize() async {
    final dbPath = await _getDatabasePath();
    final file = File(dbPath);
    if (!await file.exists()) return '0 KB';
    final bytes = await file.length();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
