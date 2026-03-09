import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/constants.dart';

part 'pb_helper_provider.g.dart';

late PocketBase globalPb;

@Riverpod(keepAlive: true)
Future<PocketBase> pbHelper(Ref ref) async {
  final prefs = await SharedPreferences.getInstance();

  final store = AsyncAuthStore(
    save: (String data) async => await prefs.setString('pb_auth', data),
    initial: prefs.getString('pb_auth'),
  );

  globalPb = PocketBase(AppConfig.baseUrl, authStore: store);
  return globalPb;
}
