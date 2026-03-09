import 'package:al_sakr/core/network/pb_helper_provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'trash_repository.g.dart';

class TrashRepository {
  final PocketBase globalPb;

  TrashRepository(this.globalPb);

  Future<List<RecordModel>> getDeletedItems(String collectionName) async {
    return await globalPb.collection(collectionName).getFullList(filter: 'is_deleted = true', sort: '-updated');
  }

  Future<void> restoreItem(String collectionName, String id) async {
    await globalPb.collection(collectionName).update(id, body: {'is_deleted': false});
  }

  Future<void> deleteForever(String collectionName, String id) async {
    await globalPb.collection(collectionName).delete(id);
  }
}

@riverpod
Future<TrashRepository> trashRepository(Ref ref) async {
  final pb = await ref.watch(pbHelperProvider.future);
  return TrashRepository(pb);
}
