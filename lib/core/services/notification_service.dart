import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // مجموعات لتتبع الإشعارات المُرسلة مسبقاً في نفس الجلسة
  static final Set<String> _notifiedLowStockIds = {};
  static final Set<String> _notifiedExpiryIds = {};

  // تعريف القناة كثابت لاستخدامه في كل مكان
  static const AndroidNotificationChannel announcementChannel =
      AndroidNotificationChannel(
        'announcements_channel', // ID
        'تنبيهات الإدارة', // Name
        description: 'قناة التنبيهات الإدارية',
        importance: Importance.max,
        playSound: true,
      );

  static Future<void> init({
    bool requestPermission = false,
    Function(NotificationResponse)? onNotificationTap,
  }) async {
    // 1. إعدادات الأندرويد
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('ic_notification');

    // 2. إعدادات اللينكس
    final LinuxInitializationSettings linuxSettings =
        LinuxInitializationSettings(defaultActionName: 'Open notification');

    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      linux: linuxSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: onNotificationTap,
    );

    // ✅ إنشاء القناة فوراً عند التهيئة
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      await androidImplementation?.createNotificationChannel(
        announcementChannel,
      );

      if (requestPermission) {
        await androidImplementation?.requestNotificationsPermission();
      }
    }
  }

  // ✅ دالة جديدة: هل فتح التطبيق بسبب الضغط على إشعار؟
  // نستخدمها في main.dart لتوجيه المستخدم
  static Future<bool> didAppLaunchFromNotification() async {
    final NotificationAppLaunchDetails? details = await _notificationsPlugin
        .getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp ?? false;
  }

  // دالة إظهار الإشعار
  static Future<void> showNotification({
    int? id,
    required String title,
    required String body,
    String? payload,
  }) async {
    // تفاصيل قناة الأندرويد
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'announcements_channel', // نفس الـ ID المستخدم في Background Service
          'تنبيهات الإدارة',
          channelDescription: 'قناة خاصة بإشعارات لوحة التحكم',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          icon: '@mipmap/ic_launcher',
        );

    // تفاصيل اللينكس
    const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.critical,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      linux: linuxDetails,
    );

    // استخدام ID ممرر أو توليد عشوائي
    final notificationId = id ?? DateTime.now().millisecondsSinceEpoch % 100000;

    await _notificationsPlugin.show(
      notificationId,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // ✅ دالة جديدة: فحص المخزون وإرسال إشعارات ذكية
  static Future<void> checkInventoryAndNotify(
    List<Map<String, dynamic>> products,
  ) async {
    for (final product in products) {
      final id = product['id']?.toString() ?? '';
      if (id.isEmpty) continue;

      final name = product['name']?.toString() ?? 'منتج غير معروف';
      final stock = (product['stock'] as num?)?.toInt() ?? 0;
      final reorderLevel = (product['reorderLevel'] as num?)?.toInt() ?? 0;

      // 1. فحص حد الخطر (نواقص)
      if (stock <= reorderLevel) {
        if (!_notifiedLowStockIds.contains(id)) {
          _notifiedLowStockIds.add(id);
          await showNotification(
            id: id.hashCode % 100000,
            title: 'تنبيه نقص مخزون ⚠️',
            body: 'المنتج "$name" وصل للحد الأدنى (الكمية الحالية: $stock).',
          );
        }
      } else {
        // إذا تم تحديث الكمية وأصبحت أكبر من حد الخطر، نزيله من القائمة
        _notifiedLowStockIds.remove(id);
      }

      // 2. فحص تاريخ الصلاحية
      if (product['expiryDate'] != null &&
          product['expiryDate'].toString().isNotEmpty) {
        try {
          DateTime exp = DateTime.parse(product['expiryDate']);
          DateTime now = DateTime.now();
          DateTime expDateOnly = DateTime(exp.year, exp.month, exp.day);
          DateTime nowDateOnly = DateTime(now.year, now.month, now.day);
          int daysLeft = expDateOnly.difference(nowDateOnly).inDays;

          if (daysLeft <= 30) {
            if (!_notifiedExpiryIds.contains(id)) {
              _notifiedExpiryIds.add(id);
              String body = daysLeft < 0
                  ? 'المنتج "$name" منتهي الصلاحية!'
                  : 'المنتج "$name" يقترب من الانتهاء (متبقي $daysLeft يوم).';
              await showNotification(
                id: (id.hashCode + 1) % 100000,
                title: 'تنبيه صلاحية ⏳',
                body: body,
              );
            }
          } else {
            // إذا تم تمديد التاريخ (مثلاً شحنة جديدة)، نزيله
            _notifiedExpiryIds.remove(id);
          }
        } catch (e) {
          // تجاهل أخطاء تحويل التاريخ
        }
      }
    }
  }
}
