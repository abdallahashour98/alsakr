import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/database/models/sync_fields_mixin.dart';

class PurchaseModel with SyncFieldsMixin {
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

  final String supplier; // FK → suppliers.id
  final double totalAmount;
  final double discount;
  final String date;
  final String notes;
  final bool isDeleted;

  PurchaseModel({
    required this.id,
    required this.localId,
    this.syncStatus = SyncStatus.synced,
    this.lastSyncedAt,
    this.pbUpdated,
    this.created,
    this.updated,
    required this.supplier,
    this.totalAmount = 0.0,
    this.discount = 0.0,
    required this.date,
    this.notes = '',
    this.isDeleted = false,
  });

  factory PurchaseModel.fromMap(Map<String, dynamic> map) {
    return PurchaseModel(
      id: map[DbConstants.colId] ?? '',
      localId: map[DbConstants.colLocalId] ?? '',
      syncStatus: map[DbConstants.colSyncStatus] ?? SyncStatus.synced,
      lastSyncedAt: map[DbConstants.colLastSyncedAt],
      pbUpdated: map[DbConstants.colPbUpdated],
      created: map[DbConstants.colCreated],
      updated: map[DbConstants.colUpdated],
      supplier: map['supplier'] ?? '',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      date: map['date'] ?? '',
      notes: map['notes'] ?? '',
      isDeleted: (map['is_deleted'] is int)
          ? map['is_deleted'] == 1
          : (map['is_deleted'] ?? false),
    );
  }

  Map<String, dynamic> toMap() => {
    ...syncFieldsToMap(),
    'supplier': supplier,
    'totalAmount': totalAmount,
    'discount': discount,
    'date': date,
    'notes': notes,
    'is_deleted': isDeleted ? 1 : 0,
  };

  Map<String, dynamic> toServerMap() => {
    'supplier': supplier,
    'totalAmount': totalAmount,
    'discount': discount,
    'date': date,
    'notes': notes,
    'is_deleted': isDeleted,
  };

  PurchaseModel copyWith({
    String? id,
    String? localId,
    String? syncStatus,
    String? lastSyncedAt,
    String? pbUpdated,
    String? created,
    String? updated,
    String? supplier,
    double? totalAmount,
    double? discount,
    String? date,
    String? notes,
    bool? isDeleted,
  }) {
    return PurchaseModel(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pbUpdated: pbUpdated ?? this.pbUpdated,
      created: created ?? this.created,
      updated: updated ?? this.updated,
      supplier: supplier ?? this.supplier,
      totalAmount: totalAmount ?? this.totalAmount,
      discount: discount ?? this.discount,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
