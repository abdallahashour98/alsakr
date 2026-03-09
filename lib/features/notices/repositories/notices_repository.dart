import 'package:al_sakr/core/network/pb_helper_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notices_repository.g.dart';

class NoticesRepository {
  final PocketBase globalPb;

  NoticesRepository(this.globalPb);

  Future<RecordModel> createAnnouncement(
    String title,
    String content,
    String priority, {
    List<File>? files,
    List<String>? targetUserIds,
  }) async {
    final body = <String, dynamic>{
      "title": title,
      "content": content,
      "priority": priority,
      "user": globalPb.authStore.model.id,
    };

    if (targetUserIds != null) {
      body["target_users"] = targetUserIds;
    }

    if (files != null && files.isNotEmpty) {
      return await globalPb.collection('announcements').create(
            body: body,
            files: files
                .map(
                  (e) => http.MultipartFile.fromBytes(
                    'image',
                    e.readAsBytesSync(),
                    filename: e.path.split('/').last,
                  ),
                )
                .toList(),
          );
    } else {
      return await globalPb.collection('announcements').create(body: body);
    }
  }

  Future<void> updateAnnouncement(
    String id,
    String title,
    String content,
    String priority, {
    List<String>? targetUserIds,
  }) async {
    final body = <String, dynamic>{
      "title": title,
      "content": content,
      "priority": priority,
      if (targetUserIds != null) "target_users": targetUserIds,
    };
    await globalPb.collection('announcements').update(id, body: body);
  }

  Future<void> deleteAnnouncement(String id) async {
    await globalPb.collection('announcements').delete(id);
  }

  Future<void> markAnnouncementAsSeen(String id) async {
    final userId = globalPb.authStore.record!.id;
    await globalPb.collection('announcements').update(id, body: {'seen_by+': userId});
  }
  
  Future<List<RecordModel>> getAnnouncements() async {
     return await globalPb.collection('announcements').getFullList(sort: '-created');
  }

  Future<List<RecordModel>> getUsers() async {
    return await globalPb.collection('users').getFullList();
  }
}

@riverpod
Future<NoticesRepository> noticesRepository(Ref ref) async {
  final pb = await ref.watch(pbHelperProvider.future);
  return NoticesRepository(pb);
}
