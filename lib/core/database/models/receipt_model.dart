import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/database/models/sync_fields_mixin.dart';

class ReceiptModel with SyncFieldsMixin {
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
  final String notes;
  final String date;
  final String method;

  ReceiptModel({
    required this.id,
    required this.localId,
    this.syncStatus = SyncStatus.synced,
    this.lastSyncedAt,
    this.pbUpdated,
    this.created,
    this.updated,
    required this.client,
    this.amount = 0.0,
    this.notes = '',
    required this.date,
    this.method = 'cash',
  });

  factory ReceiptModel.fromMap(Map<String, dynamic> map) {
    return ReceiptModel(
      id: map[DbConstants.colId] ?? '',
      localId: map[DbConstants.colLocalId] ?? '',
      syncStatus: map[DbConstants.colSyncStatus] ?? SyncStatus.synced,
      lastSyncedAt: map[DbConstants.colLastSyncedAt],
      pbUpdated: map[DbConstants.colPbUpdated],
      created: map[DbConstants.colCreated],
      updated: map[DbConstants.colUpdated],
      client: map['client'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] ?? '',
      date: map['date'] ?? '',
      method: map['method'] ?? 'cash',
    );
  }

  Map<String, dynamic> toMap() => {
    ...syncFieldsToMap(),
    'client': client,
    'amount': amount,
    'notes': notes,
    'date': date,
    'method': method,
  };

  Map<String, dynamic> toServerMap() => {
    'client': client,
    'amount': amount,
    'notes': notes,
    'date': date,
    'method': method,
  };

  ReceiptModel copyWith({
    String? id,
    String? localId,
    String? syncStatus,
    String? lastSyncedAt,
    String? pbUpdated,
    String? created,
    String? updated,
    String? client,
    double? amount,
    String? notes,
    String? date,
    String? method,
  }) {
    return ReceiptModel(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pbUpdated: pbUpdated ?? this.pbUpdated,
      created: created ?? this.created,
      updated: updated ?? this.updated,
      client: client ?? this.client,
      amount: amount ?? this.amount,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      method: method ?? this.method,
    );
  }
}
