import 'package:flutter/material.dart';
import 'package:al_sakr/core/network/pb_helper_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:al_sakr/core/network/pb_helper.dart';
import 'package:al_sakr/core/database/database_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:al_sakr/core/database/database_helper.dart';

class SettingsService {
  // ============================================================
  // 1. إعدادات الشركة (من قاعدة البيانات)
  // ============================================================

  Future<Map<String, dynamic>> getCompanySettings([WidgetRef? ref]) async {
    try {
      // Try local DB first
      final db = ref != null
          ? await ref.read(localDatabaseProvider.future)
          : await DatabaseHelper().database;
      final list = await db.query('settings', limit: 1);
      if (list.isNotEmpty) {
        return list.first;
      }

      // Fallback to PB
      final records = await globalPb
          .collection('settings')
          .getList(page: 1, perPage: 1);
      if (records.items.isNotEmpty) {
        final data = PBHelper.recordToMap(records.items.first);

        // Filter out keys that don't belong to settings SQLite schema
        final allowedKeys = [
          'id',
          'local_id',
          'sync_status',
          'last_synced_at',
          'pb_updated',
          'created',
          'updated',
          'collectionId',
          'collectionName',
          'company_name',
          'address',
          'phone',
          'mobile',
          'website',
          'email',
        ];
        final dbData = Map<String, dynamic>.from(data)
          ..removeWhere((k, v) => !allowedKeys.contains(k));

        // Save to local DB
        await db.insert(
          'settings',
          dbData,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return data;
      }
    } catch (e) {
      // ignore
    }
    return {};
  }

  Future<void> saveCompanySettings(
    WidgetRef ref,
    Map<String, dynamic> data,
  ) async {
    try {
      final db = await ref.read(localDatabaseProvider.future);

      data['id'] =
          data['id'] ?? 'company_settings_id'; // Ensure ID exists for sync

      final allowedKeys = [
        'id',
        'local_id',
        'sync_status',
        'last_synced_at',
        'pb_updated',
        'created',
        'updated',
        'collectionId',
        'collectionName',
        'company_name',
        'address',
        'phone',
        'mobile',
        'website',
        'email',
      ];
      final dbData = Map<String, dynamic>.from(data)
        ..removeWhere((k, v) => !allowedKeys.contains(k));

      // Ensure sync_status marks it as needing upload
      dbData['sync_status'] = 'pending_update';

      // Local save
      final existing = await db.query('settings', limit: 1);
      if (existing.isNotEmpty) {
        dbData['id'] = existing.first['id'];
        data['id'] = existing
            .first['id']; // update the original payload ID too for pb sync
        await db.update(
          'settings',
          dbData,
          where: 'id = ?',
          whereArgs: [dbData['id']],
        );
      } else {
        dbData['sync_status'] = 'pending_create';
        await db.insert('settings', dbData);
      }

      // Try uploading to PB if online, but don't crash if offline
      if (globalPb.authStore.isValid) {
        try {
          if (existing.isNotEmpty) {
            await globalPb
                .collection('settings')
                .update(data['id'], body: data);
          } else {
            await globalPb.collection('settings').create(body: data);
          }
          // If successful, mark as synced locally
          await db.update(
            'settings',
            {'sync_status': 'synced'},
            where: 'id = ?',
            whereArgs: [dbData['id']],
          );
        } catch (e) {
          debugPrint('Offline or network error syncing settings: $e');
        }
      }
    } catch (e) {
      debugPrint('Local DB error saving settings: $e');
      rethrow;
    }
  }

  // ============================================================
  // 2. إعدادات التطبيق المحلية (Theme & Language) - الدوال الناقصة
  // ============================================================

  /// حفظ وضع الثيم (Dark/Light)
  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.toString());
  }

  /// استرجاع وضع الثيم
  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    String? saved = prefs.getString('theme_mode');

    if (saved == 'ThemeMode.dark') return ThemeMode.dark;
    if (saved == 'ThemeMode.light') return ThemeMode.light;

    return ThemeMode.system;
  }

  /// حفظ اللغة
  Future<void> saveLocale(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_lang', languageCode);
  }

  /// استرجاع اللغة
  Future<Locale> getLocale() async {
    final prefs = await SharedPreferences.getInstance();
    String? lang = prefs.getString('app_lang');
    if (lang == 'en') return const Locale('en');
    // الافتراضي عربي
    return const Locale('ar');
  }

  // ============================================================
  // 3. إشعارات المخزون
  // ============================================================

  /// حفظ حالة تفعيل إشعارات المخزون
  Future<void> saveInventoryNotifications(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('inventory_notifications', enabled);
  }

  /// استرجاع حالة تفعيل إشعارات المخزون (الافتراضي: مفعّل)
  Future<bool> getInventoryNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('inventory_notifications') ?? true;
  }
}
