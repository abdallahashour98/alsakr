import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/database/models/sync_fields_mixin.dart';

class ReturnModel with SyncFieldsMixin {
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

  final String sale; // FK → sales.id
  final String client; // FK → clients.id
  final double totalAmount;
  final double discount;
  final String date;
  final String notes;
  final bool isComplete;

  ReturnModel({
    required this.id,
    required this.localId,
    this.syncStatus = SyncStatus.synced,
    this.lastSyncedAt,
    this.pbUpdated,
    this.created,
    this.updated,
    required this.sale,
    required this.client,
    this.totalAmount = 0.0,
    this.discount = 0.0,
    required this.date,
    this.notes = '',
    this.isComplete = false,
  });

  factory ReturnModel.fromMap(Map<String, dynamic> map) {
    return ReturnModel(
      id: map[DbConstants.colId] ?? '',
      localId: map[DbConstants.colLocalId] ?? '',
      syncStatus: map[DbConstants.colSyncStatus] ?? SyncStatus.synced,
      lastSyncedAt: map[DbConstants.colLastSyncedAt],
      pbUpdated: map[DbConstants.colPbUpdated],
      created: map[DbConstants.colCreated],
      updated: map[DbConstants.colUpdated],
      sale: map['sale'] ?? '',
      client: map['client'] ?? '',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      date: map['date'] ?? '',
      notes: map['notes'] ?? '',
      isComplete: (map['is_complete'] is int)
          ? map['is_complete'] == 1
          : (map['is_complete'] ?? false),
    );
  }

  Map<String, dynamic> toMap() => {
    ...syncFieldsToMap(),
    'sale': sale,
    'client': client,
    'totalAmount': totalAmount,
    'discount': discount,
    'date': date,
    'notes': notes,
    'is_complete': isComplete ? 1 : 0,
  };

  Map<String, dynamic> toServerMap() => {
    'sale': sale,
    'client': client,
    'totalAmount': totalAmount,
    'discount': discount,
    'date': date,
    'notes': notes,
    'is_complete': isComplete,
  };

  ReturnModel copyWith({
    String? id,
    String? localId,
    String? syncStatus,
    String? lastSyncedAt,
    String? pbUpdated,
    String? created,
    String? updated,
    String? sale,
    String? client,
    double? totalAmount,
    double? discount,
    String? date,
    String? notes,
    bool? isComplete,
  }) {
    return ReturnModel(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pbUpdated: pbUpdated ?? this.pbUpdated,
      created: created ?? this.created,
      updated: updated ?? this.updated,
      sale: sale ?? this.sale,
      client: client ?? this.client,
      totalAmount: totalAmount ?? this.totalAmount,
      discount: discount ?? this.discount,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}
