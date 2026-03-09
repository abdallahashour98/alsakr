import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/database/models/sync_fields_mixin.dart';

class DeliveryOrderModel with SyncFieldsMixin {
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

  final String client; // FK → clients.id
  final String supplyOrderNumber;
  final String manualNo;
  final String address;
  final String date;
  final String notes;
  final bool isComplete;
  final bool isLocked;
  final String image;
  final bool isDeleted;

  DeliveryOrderModel({
    required this.id,
    required this.localId,
    this.syncStatus = SyncStatus.synced,
    this.lastSyncedAt,
    this.pbUpdated,
    this.created,
    this.updated,
    required this.client,
    this.supplyOrderNumber = '',
    this.manualNo = '',
    this.address = '',
    required this.date,
    this.notes = '',
    this.isComplete = false,
    this.isLocked = false,
    this.image = '',
    this.isDeleted = false,
  });

  factory DeliveryOrderModel.fromMap(Map<String, dynamic> map) {
    return DeliveryOrderModel(
      id: map[DbConstants.colId] ?? '',
      localId: map[DbConstants.colLocalId] ?? '',
      syncStatus: map[DbConstants.colSyncStatus] ?? SyncStatus.synced,
      lastSyncedAt: map[DbConstants.colLastSyncedAt],
      pbUpdated: map[DbConstants.colPbUpdated],
      created: map[DbConstants.colCreated],
      updated: map[DbConstants.colUpdated],
      client: map['client'] ?? '',
      supplyOrderNumber: map['supplyOrderNumber'] ?? '',
      manualNo: map['manualNo'] ?? '',
      address: map['address'] ?? '',
      date: map['date'] ?? '',
      notes: map['notes'] ?? '',
      isComplete: (map['is_complete'] is int)
          ? map['is_complete'] == 1
          : (map['is_complete'] ?? false),
      isLocked: (map['isLocked'] is int)
          ? map['isLocked'] == 1
          : (map['isLocked'] ?? false),
      image: map['image'] ?? '',
      isDeleted: (map['is_deleted'] is int)
          ? map['is_deleted'] == 1
          : (map['is_deleted'] ?? false),
    );
  }

  Map<String, dynamic> toMap() => {
    ...syncFieldsToMap(),
    'client': client,
    'supplyOrderNumber': supplyOrderNumber,
    'manualNo': manualNo,
    'address': address,
    'date': date,
    'notes': notes,
    'is_complete': isComplete ? 1 : 0,
    'isLocked': isLocked ? 1 : 0,
    'image': image,
    'is_deleted': isDeleted ? 1 : 0,
  };

  Map<String, dynamic> toServerMap() => {
    'client': client,
    'supplyOrderNumber': supplyOrderNumber,
    'manualNo': manualNo,
    'address': address,
    'date': date,
    'notes': notes,
    'is_complete': isComplete,
    'isLocked': isLocked,
    'is_deleted': isDeleted,
  };

  DeliveryOrderModel copyWith({
    String? id,
    String? localId,
    String? syncStatus,
    String? lastSyncedAt,
    String? pbUpdated,
    String? created,
    String? updated,
    String? client,
    String? supplyOrderNumber,
    String? manualNo,
    String? address,
    String? date,
    String? notes,
    bool? isComplete,
    bool? isLocked,
    String? image,
    bool? isDeleted,
  }) {
    return DeliveryOrderModel(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pbUpdated: pbUpdated ?? this.pbUpdated,
      created: created ?? this.created,
      updated: updated ?? this.updated,
      client: client ?? this.client,
      supplyOrderNumber: supplyOrderNumber ?? this.supplyOrderNumber,
      manualNo: manualNo ?? this.manualNo,
      address: address ?? this.address,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      isComplete: isComplete ?? this.isComplete,
      isLocked: isLocked ?? this.isLocked,
      image: image ?? this.image,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
