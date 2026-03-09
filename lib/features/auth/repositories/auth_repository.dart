import 'package:al_sakr/core/network/pb_helper_provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_repository.g.dart';

class AuthRepository {
  final PocketBase globalPb;

  AuthRepository(this.globalPb);

  bool get isLoggedIn => globalPb.authStore.isValid;

  String? get currentAdminId => globalPb.authStore.model?.id;

  Future<void> login(String email, String password) async {
    try {
      await globalPb.collection('users').authWithPassword(email, password);
    } catch (e) {
      try {
        await globalPb.admins.authWithPassword(email, password);
      } catch (e2) {
        throw Exception('Login failed. Please check your credentials.');
      }
    }
  }

  void logout() {
    globalPb.authStore.clear();
  }
}

@riverpod
Future<AuthRepository> authRepository(Ref ref) async {
  final pb = await ref.watch(pbHelperProvider.future);
  return AuthRepository(pb);
}
