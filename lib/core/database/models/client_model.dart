import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/database/models/sync_fields_mixin.dart';

class ClientModel with SyncFieldsMixin {
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

  final String name;
  final String phone;
  final String address;
  final double balance;
  final bool isDeleted;

  ClientModel({
    required this.id,
    required this.localId,
    this.syncStatus = SyncStatus.synced,
    this.lastSyncedAt,
    this.pbUpdated,
    this.created,
    this.updated,
    required this.name,
    this.phone = '',
    this.address = '',
    this.balance = 0.0,
    this.isDeleted = false,
  });

  /// Create from a local SQLite row.
  factory ClientModel.fromMap(Map<String, dynamic> map) {
    return ClientModel(
      id: map[DbConstants.colId] ?? '',
      localId: map[DbConstants.colLocalId] ?? '',
      syncStatus: map[DbConstants.colSyncStatus] ?? SyncStatus.synced,
      lastSyncedAt: map[DbConstants.colLastSyncedAt],
      pbUpdated: map[DbConstants.colPbUpdated],
      created: map[DbConstants.colCreated],
      updated: map[DbConstants.colUpdated],
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      isDeleted: (map['is_deleted'] is int)
          ? map['is_deleted'] == 1
          : (map['is_deleted'] ?? false),
    );
  }

  /// Convert to a map for local SQLite insert/update.
  Map<String, dynamic> toMap() => {
    ...syncFieldsToMap(),
    'name': name,
    'phone': phone,
    'address': address,
    'balance': balance,
    'is_deleted': isDeleted ? 1 : 0,
  };

  /// Convert to a map suitable for sending to PocketBase (excludes sync fields).
  Map<String, dynamic> toServerMap() => {
    'name': name,
    'phone': phone,
    'address': address,
    'balance': balance,
    'is_deleted': isDeleted,
  };

  ClientModel copyWith({
    String? id,
    String? localId,
    String? syncStatus,
    String? lastSyncedAt,
    String? pbUpdated,
    String? created,
    String? updated,
    String? name,
    String? phone,
    String? address,
    double? balance,
    bool? isDeleted,
  }) {
    return ClientModel(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pbUpdated: pbUpdated ?? this.pbUpdated,
      created: created ?? this.created,
      updated: updated ?? this.updated,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      balance: balance ?? this.balance,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
