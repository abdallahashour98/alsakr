// import 'package:al_sakr/features/sales/controllers/sales_controller.dart';
// import 'package:al_sakr/features/purchases/controllers/purchases_controller.dart';
// import 'package:al_sakr/features/store/controllers/store_controller.dart';
// import 'package:al_sakr/features/trash/controllers/trash_controller.dart';
// import 'package:al_sakr/features/notices/controllers/notices_controller.dart';
// import 'package:al_sakr/features/auth/controllers/auth_controller.dart';
import 'package:al_sakr/core/network/pb_helper_provider.dart';
import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
// import '../network/pb_helper_provider.dart';
import 'package:al_sakr/core/services/notification_service.dart';
// import '../../main.dart';

part 'app_init_provider.g.dart';

@Riverpod(keepAlive: true)
class AppInitNotifier extends _$AppInitNotifier {
  @override
  FutureOr<bool> build() async {
    return _checkServer();
  }

  Future<bool> _checkServer() async {
    final pb = await ref.watch(pbHelperProvider.future);
    final health = await globalPb.health.check().timeout(const Duration(seconds: 5));

    if (health.code == 200) {
      bool launchedFromNotification = false;
      if (Platform.isAndroid || Platform.isIOS) {
        launchedFromNotification = await NotificationService.didAppLaunchFromNotification();
      }

      if (launchedFromNotification && globalPb.authStore.isValid) {
        // We will handle navigation in UI side based on this provider's result later.
      }
      return true; // Successfully connected
    }
    return false;
  }

  Future<void> retry() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _checkServer());
  }
}
