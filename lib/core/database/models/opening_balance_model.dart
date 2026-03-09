import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/database/models/sync_fields_mixin.dart';

class OpeningBalanceModel with SyncFieldsMixin {
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
  final double amount;
  final String date;
  final String notes;

  OpeningBalanceModel({
    required this.id,
    required this.localId,
    this.syncStatus = SyncStatus.synced,
    this.lastSyncedAt,
    this.pbUpdated,
    this.created,
    this.updated,
    required this.client,
    this.amount = 0.0,
    required this.date,
    this.notes = '',
  });

  factory OpeningBalanceModel.fromMap(Map<String, dynamic> map) {
    return OpeningBalanceModel(
      id: map[DbConstants.colId] ?? '',
      localId: map[DbConstants.colLocalId] ?? '',
      syncStatus: map[DbConstants.colSyncStatus] ?? SyncStatus.synced,
      lastSyncedAt: map[DbConstants.colLastSyncedAt],
      pbUpdated: map[DbConstants.colPbUpdated],
      created: map[DbConstants.colCreated],
      updated: map[DbConstants.colUpdated],
      client: map['client'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      date: map['date'] ?? '',
      notes: map['notes'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    ...syncFieldsToMap(),
    'client': client,
    'amount': amount,
    'date': date,
    'notes': notes,
  };

  Map<String, dynamic> toServerMap() => {
    'client': client,
    'amount': amount,
    'date': date,
    'notes': notes,
  };

  OpeningBalanceModel copyWith({
    String? id,
    String? localId,
    String? syncStatus,
    String? lastSyncedAt,
    String? pbUpdated,
    String? created,
    String? updated,
    String? client,
    double? amount,
    String? date,
    String? notes,
  }) {
    return OpeningBalanceModel(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pbUpdated: pbUpdated ?? this.pbUpdated,
      created: created ?? this.created,
      updated: updated ?? this.updated,
      client: client ?? this.client,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      notes: notes ?? this.notes,
    );
  }
}
