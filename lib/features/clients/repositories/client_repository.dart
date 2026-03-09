import 'package:al_sakr/core/network/pb_helper_provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'client_repository.g.dart';

class ClientRepository {
  final PocketBase globalPb;

  ClientRepository(this.globalPb);

  Stream<List<RecordModel>> watchClients() {
    // Basic streaming setup for Riverpod
    // Since PocketBase SDK handles streams differently, we can wrap getFullList 
    // and subscribe to changes.
    // NOTE: This implementation will be refined in the controller.
    throw UnimplementedError("Stream handled in controller for now");
  }

  Future<List<RecordModel>> getClients() async {
    return await globalPb.collection('clients').getFullList(sort: 'name');
  }

  Future<RecordModel> createClient(Map<String, dynamic> data) async {
    return await globalPb.collection('clients').create(body: data);
  }

  Future<RecordModel> updateClient(String id, Map<String, dynamic> data) async {
    return await globalPb.collection('clients').update(id, body: data);
  }

  Future<void> deleteClient(String id) async {
    await globalPb.collection('clients').delete(id);
  }
}

@riverpod
Future<ClientRepository> clientRepository(Ref ref) async {
  final pb = await ref.watch(pbHelperProvider.future);
  return ClientRepository(pb);
}
