import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/database/models/sync_fields_mixin.dart';

class ExpenseModel with SyncFieldsMixin {
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

  final String description;
  final double amount;
  final String category;
  final String date;
  final bool isDeleted;

  ExpenseModel({
    required this.id,
    required this.localId,
    this.syncStatus = SyncStatus.synced,
    this.lastSyncedAt,
    this.pbUpdated,
    this.created,
    this.updated,
    this.description = '',
    this.amount = 0.0,
    this.category = '',
    required this.date,
    this.isDeleted = false,
  });

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    return ExpenseModel(
      id: map[DbConstants.colId] ?? '',
      localId: map[DbConstants.colLocalId] ?? '',
      syncStatus: map[DbConstants.colSyncStatus] ?? SyncStatus.synced,
      lastSyncedAt: map[DbConstants.colLastSyncedAt],
      pbUpdated: map[DbConstants.colPbUpdated],
      created: map[DbConstants.colCreated],
      updated: map[DbConstants.colUpdated],
      description: map['description'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] ?? '',
      date: map['date'] ?? '',
      isDeleted: (map['is_deleted'] is int)
          ? map['is_deleted'] == 1
          : (map['is_deleted'] ?? false),
    );
  }

  Map<String, dynamic> toMap() => {
    ...syncFieldsToMap(),
    'description': description,
    'amount': amount,
    'category': category,
    'date': date,
    'is_deleted': isDeleted ? 1 : 0,
  };

  Map<String, dynamic> toServerMap() => {
    'description': description,
    'amount': amount,
    'category': category,
    'date': date,
    'is_deleted': isDeleted,
  };

  ExpenseModel copyWith({
    String? id,
    String? localId,
    String? syncStatus,
    String? lastSyncedAt,
    String? pbUpdated,
    String? created,
    String? updated,
    String? description,
    double? amount,
    String? category,
    String? date,
    bool? isDeleted,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pbUpdated: pbUpdated ?? this.pbUpdated,
      created: created ?? this.created,
      updated: updated ?? this.updated,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
