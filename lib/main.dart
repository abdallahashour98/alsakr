import 'package:al_sakr/core/network/pb_helper_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:io';
import 'package:al_sakr/features/dashboard/presentations/dashboard_screen.dart';
import 'package:al_sakr/features/notices/presentations/notices_screen.dart'; // ✅ تأكد من استيراد هذا الملف
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // ✅ تمت الإضافة
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:al_sakr/core/network/pb_helper.dart';
import 'package:al_sakr/core/sync/connectivity_service.dart';
import 'package:al_sakr/core/database/database_helper.dart';
import 'package:al_sakr/features/auth/presentations/login_screen.dart';
import 'package:al_sakr/core/services/notification_service.dart';
import 'package:al_sakr/core/services/background_listener.dart';

import 'package:al_sakr/core/services/settings_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);
final ValueNotifier<Locale> localeNotifier = ValueNotifier(const Locale('en'));

// ✅ دالة موحدة للتعامل مع الضغط على الإشعار
void onNotificationTap(NotificationResponse details) {
  if (details.payload == 'navigate_to_notices') {
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(builder: (context) => const NoticesScreen()),
      );
    }
  }
}

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      final settings = SettingsService();
      final savedTheme = await settings.getThemeMode();
      themeNotifier.value = savedTheme;

      // 2. تحميل اللغة
      final savedLocale = await settings.getLocale();
      localeNotifier.value = savedLocale;

      try {
        await NotificationService.init(
          requestPermission: true, // نطلب الصلاحية هنا
          onNotificationTap: onNotificationTap,
        );

        if (Platform.isAndroid) await Permission.notification.request();

        // 2. تهيئة PBHelper وتمرير دالة التوجيه أيضاً لضمان عدم مسحها
        await PBHelper.init(onNotificationTap: onNotificationTap);

        // 3. تهيئة قاعدة البيانات المحلية (SQLite)
        await DatabaseHelper().database;
        print('✅ Local database initialized');

        if (Platform.isAndroid || Platform.isIOS) {
          // 📱 للموبايل: شغل خدمة الخلفية فقط
          await initializeService();
        }
        // 💻 للكمبيوتر: مستمع الخلفية سيعمل عند فتح الشاشة
      } catch (e) {
        print("Error in main: $e");
      }
      runApp(const ProviderScope(child: MyApp()));
    },
    (error, stack) {
      print("Zoned Error: $error");
    },
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentTheme, _) {
        return ValueListenableBuilder<Locale>(
          valueListenable: localeNotifier,
          builder: (context, currentLocale, _) {
            return MaterialApp(
              navigatorKey: navigatorKey,
              title: 'Al Sakr',
              debugShowCheckedModeBanner: false,
              supportedLocales: const [Locale('ar'), Locale('en')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              locale: currentLocale,
              themeMode: currentTheme,
              theme: ThemeData(
                useMaterial3: true,
                colorSchemeSeed: Colors.blue,
                brightness: Brightness.light,
                fontFamily: 'Cairo',
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                colorSchemeSeed: Colors.blue,
                brightness: Brightness.dark,
                fontFamily: 'Cairo',
              ),
              home: const ConnectionCheckWrapper(),
            );
          },
        );
      },
    );
  }
}

class ConnectionCheckWrapper extends ConsumerStatefulWidget {
  const ConnectionCheckWrapper({super.key});

  @override
  ConsumerState<ConnectionCheckWrapper> createState() =>
      _ConnectionCheckWrapperState();
}

class _ConnectionCheckWrapperState
    extends ConsumerState<ConnectionCheckWrapper> {
  bool _isConnected = false;
  // Always show the loading screen initially to give the connection check a chance
  bool _isLoading = true;
  bool _isOfflineMode = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkServer();
  }

  Future<void> _checkServer() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _isOfflineMode = false;
    });

    // We must initialize PBHelper (and local authStore) regardless of online status.
    await PBHelper.init(onNotificationTap: onNotificationTap);

    try {
      final health = await globalPb.health.check().timeout(
        const Duration(seconds: 4),
      );

      if (health.code == 200) {
        bool launchedFromNotification = false;
        if (Platform.isAndroid || Platform.isIOS) {
          launchedFromNotification =
              await NotificationService.didAppLaunchFromNotification();
        }

        if (mounted) {
          setState(() {
            _isConnected = true;
            _isLoading = false;
          });

          if (launchedFromNotification && globalPb.authStore.isValid) {
            Future.delayed(const Duration(milliseconds: 500), () {
              navigatorKey.currentState?.push(
                MaterialPageRoute(builder: (context) => const NoticesScreen()),
              );
            });
          }
        }
      } else {
        throw Exception('Server returned non-200 status');
      }
    } catch (e) {
      if (mounted) {
        // إذا كان المستخدم مسجل دخوله مسبقاً، نسمح له بالدخول في وضع أوفلاين
        if (globalPb.authStore.isValid) {
          setState(() {
            _isConnected = false;
            _isLoading = false;
            _isOfflineMode = true;
          });
        } else {
          setState(() {
            _isConnected = false;
            _isLoading = false;
            _errorMessage = "تعذر الاتصال بالسيرفر. تأكد من اتصالك بالشبكة.";
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to real connectivity status to automatically recover from offline mode
    ref.listen<AsyncValue<bool>>(connectivityStatusProvider, (previous, next) {
      if (next.value == true && _isOfflineMode) {
        setState(() {
          _isOfflineMode = false;
          _isConnected = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم استعادة الاتصال بالسيرفر!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else if (next.value == false && _isConnected) {
        setState(() {
          _isOfflineMode = true;
          _isConnected = false;
        });
      }
    });

    // حالة التحميل (تظهر فقط لو مفيش تسجيل دخول مسبق)
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/splash_logo.png', width: 150, height: 150),
              const SizedBox(height: 30),
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text(
                "جاري الاتصال بالنظام...",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // إذا كان المستخدم مسجلاً للدخول، يتم عرضه فوراً (متصل أو وضع أوفلاين)
    if (globalPb.authStore.isValid) {
      if (_isOfflineMode || !_isConnected) {
        return Scaffold(
          body: Column(
            children: [
              // شريط تحذير أوفلاين
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(color: Colors.orange[800]),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.wifi_off_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          "وضع عدم الاتصال - البيانات المحفوظة محلياً",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _checkServer,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                          "إعادة الاتصال",
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          backgroundColor: Colors.white.withOpacity(0.15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // عرض الداشبورد
              const Expanded(child: DashboardScreen()),
            ],
          ),
        );
      }
      // متصل ولا يوجد وضع أوفلاين
      return const DashboardScreen();
    }

    // فشل الاتصال ولم يسبق تسجيل الدخول
    if (!_isConnected) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_off_rounded,
                    size: 60,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "لا يوجد اتصال بالسيرفر",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  "يجب الاتصال بالسيرفر لتسجيل الدخول لأول مرة",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: 200,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _checkServer,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text(
                      "إعادة المحاولة",
                      style: TextStyle(fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // متصل بالسيرفر ولم يسبق الدخول
    return const LoginScreen();
  }
}
