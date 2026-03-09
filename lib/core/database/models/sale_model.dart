import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/database/models/sync_fields_mixin.dart';

class SaleModel with SyncFieldsMixin {
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
  final double totalAmount;
  final double discount;
  final double taxAmount;
  final double whtAmount;
  final double netAmount;
  final String paymentType;
  final String date;
  final String referenceNumber;
  final bool isDeleted;
  final bool isComplete;

  SaleModel({
    required this.id,
    required this.localId,
    this.syncStatus = SyncStatus.synced,
    this.lastSyncedAt,
    this.pbUpdated,
    this.created,
    this.updated,
    required this.client,
    this.totalAmount = 0.0,
    this.discount = 0.0,
    this.taxAmount = 0.0,
    this.whtAmount = 0.0,
    this.netAmount = 0.0,
    this.paymentType = 'cash',
    required this.date,
    this.referenceNumber = '',
    this.isDeleted = false,
    this.isComplete = false,
  });

  factory SaleModel.fromMap(Map<String, dynamic> map) {
    return SaleModel(
      id: map[DbConstants.colId] ?? '',
      localId: map[DbConstants.colLocalId] ?? '',
      syncStatus: map[DbConstants.colSyncStatus] ?? SyncStatus.synced,
      lastSyncedAt: map[DbConstants.colLastSyncedAt],
      pbUpdated: map[DbConstants.colPbUpdated],
      created: map[DbConstants.colCreated],
      updated: map[DbConstants.colUpdated],
      client: map['client'] ?? '',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['taxAmount'] as num?)?.toDouble() ?? 0.0,
      whtAmount: (map['whtAmount'] as num?)?.toDouble() ?? 0.0,
      netAmount: (map['netAmount'] as num?)?.toDouble() ?? 0.0,
      paymentType: map['paymentType'] ?? 'cash',
      date: map['date'] ?? '',
      referenceNumber: map['referenceNumber'] ?? '',
      isDeleted: (map['is_deleted'] is int)
          ? map['is_deleted'] == 1
          : (map['is_deleted'] ?? false),
      isComplete: (map['is_complete'] is int)
          ? map['is_complete'] == 1
          : (map['is_complete'] ?? false),
    );
  }

  Map<String, dynamic> toMap() => {
    ...syncFieldsToMap(),
    'client': client,
    'totalAmount': totalAmount,
    'discount': discount,
    'taxAmount': taxAmount,
    'whtAmount': whtAmount,
    'netAmount': netAmount,
    'paymentType': paymentType,
    'date': date,
    'referenceNumber': referenceNumber,
    'is_deleted': isDeleted ? 1 : 0,
    'is_complete': isComplete ? 1 : 0,
  };

  Map<String, dynamic> toServerMap() => {
    'client': client,
    'totalAmount': totalAmount,
    'discount': discount,
    'taxAmount': taxAmount,
    'whtAmount': whtAmount,
    'netAmount': netAmount,
    'paymentType': paymentType,
    'date': date,
    'referenceNumber': referenceNumber,
    'is_deleted': isDeleted,
    'is_complete': isComplete,
  };

  SaleModel copyWith({
    String? id,
    String? localId,
    String? syncStatus,
    String? lastSyncedAt,
    String? pbUpdated,
    String? created,
    String? updated,
    String? client,
    double? totalAmount,
    double? discount,
    double? taxAmount,
    double? whtAmount,
    double? netAmount,
    String? paymentType,
    String? date,
    String? referenceNumber,
    bool? isDeleted,
    bool? isComplete,
  }) {
    return SaleModel(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pbUpdated: pbUpdated ?? this.pbUpdated,
      created: created ?? this.created,
      updated: updated ?? this.updated,
      client: client ?? this.client,
      totalAmount: totalAmount ?? this.totalAmount,
      discount: discount ?? this.discount,
      taxAmount: taxAmount ?? this.taxAmount,
      whtAmount: whtAmount ?? this.whtAmount,
      netAmount: netAmount ?? this.netAmount,
      paymentType: paymentType ?? this.paymentType,
      date: date ?? this.date,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      isDeleted: isDeleted ?? this.isDeleted,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}
