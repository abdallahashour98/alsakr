import 'dart:convert';
import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/database/models/sync_fields_mixin.dart';

class AnnouncementModel with SyncFieldsMixin {
  @override
  final String id;
  @override
  final String localId;
  @override
  final String syncStatus;
  @override
  final String? lastSyncedAt;
  @override
  final String? pbUpdated;
  @override
  final String? created;
  @override
  final String? updated;

  final String title;
  final String content;
  final String priority;
  final String user; // FK → users.id (creator)
  final List<String> targetUsers; // list of user IDs
  final List<String> seenBy; // list of user IDs who have seen it
  final String image;

  AnnouncementModel({
    required this.id,
    required this.localId,
    this.syncStatus = SyncStatus.synced,
    this.lastSyncedAt,
    this.pbUpdated,
    this.created,
    this.updated,
    this.title = '',
    this.content = '',
    this.priority = 'normal',
    this.user = '',
    this.targetUsers = const [],
    this.seenBy = const [],
    this.image = '',
  });

  factory AnnouncementModel.fromMap(Map<String, dynamic> map) {
    return AnnouncementModel(
      id: map[DbConstants.colId] ?? '',
      localId: map[DbConstants.colLocalId] ?? '',
      syncStatus: map[DbConstants.colSyncStatus] ?? SyncStatus.synced,
      lastSyncedAt: map[DbConstants.colLastSyncedAt],
      pbUpdated: map[DbConstants.colPbUpdated],
      created: map[DbConstants.colCreated],
      updated: map[DbConstants.colUpdated],
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      priority: map['priority'] ?? 'normal',
      user: map['user'] ?? '',
      targetUsers: _decodeStringList(map['target_users']),
      seenBy: _decodeStringList(map['seen_by']),
      image: map['image'] ?? '',
    );
  }

  /// Decode a JSON-encoded list or a comma-separated string into a List<String>.
  static List<String> _decodeStringList(dynamic value) {
    if (value == null || value == '') return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
      // Fallback: comma-separated
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  Map<String, dynamic> toMap() => {
    ...syncFieldsToMap(),
    'title': title,
    'content': content,
    'priority': priority,
    'user': user,
    'target_users': jsonEncode(targetUsers),
    'seen_by': jsonEncode(seenBy),
    'image': image,
  };

  Map<String, dynamic> toServerMap() => {
    'title': title,
    'content': content,
    'priority': priority,
    'user': user,
    'target_users': targetUsers,
    'seen_by': seenBy,
  };

  AnnouncementModel copyWith({
    String? id,
    String? localId,
    String? syncStatus,
    String? lastSyncedAt,
    String? pbUpdated,
    String? created,
    String? updated,
    String? title,
    String? content,
    String? priority,
    String? user,
    List<String>? targetUsers,
    List<String>? seenBy,
    String? image,
  }) {
    return AnnouncementModel(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pbUpdated: pbUpdated ?? this.pbUpdated,
      created: created ?? this.created,
      updated: updated ?? this.updated,
      title: title ?? this.title,
      content: content ?? this.content,
      priority: priority ?? this.priority,
      user: user ?? this.user,
      targetUsers: targetUsers ?? this.targetUsers,
      seenBy: seenBy ?? this.seenBy,
      image: image ?? this.image,
    );
  }
}
