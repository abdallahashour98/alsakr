import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/database/models/sync_fields_mixin.dart';

/// A line item in a return. The [stockDelta] field captures the quantity change
/// for atomic inventory updates during upsync (positive for returns, e.g., +3).
class ReturnItemModel with SyncFieldsMixin {
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

  final String
  returnId; // FK → returns.id (named return_id in DB to avoid keyword)
  final String product; // FK → products.id
  final int quantity;
  final double price;
  final int stockDelta; // Positive for returns (e.g., +3)

  ReturnItemModel({
    required this.id,
    required this.localId,
    this.syncStatus = SyncStatus.synced,
    this.lastSyncedAt,
    this.pbUpdated,
    this.created,
    this.updated,
    required this.returnId,
    required this.product,
    this.quantity = 0,
    this.price = 0.0,
    this.stockDelta = 0,
  });

  factory ReturnItemModel.fromMap(Map<String, dynamic> map) {
    return ReturnItemModel(
      id: map[DbConstants.colId] ?? '',
      localId: map[DbConstants.colLocalId] ?? '',
      syncStatus: map[DbConstants.colSyncStatus] ?? SyncStatus.synced,
      lastSyncedAt: map[DbConstants.colLastSyncedAt],
      pbUpdated: map[DbConstants.colPbUpdated],
      created: map[DbConstants.colCreated],
      updated: map[DbConstants.colUpdated],
      returnId: map['return_id'] ?? '',
      product: map['product'] ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      stockDelta: (map['stock_delta'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    ...syncFieldsToMap(),
    'return_id': returnId,
    'product': product,
    'quantity': quantity,
    'price': price,
    'stock_delta': stockDelta,
  };

  Map<String, dynamic> toServerMap() => {
    'return': returnId,
    'product': product,
    'quantity': quantity,
    'price': price,
  };

  ReturnItemModel copyWith({
    String? id,
    String? localId,
    String? syncStatus,
    String? lastSyncedAt,
    String? pbUpdated,
    String? created,
    String? updated,
    String? returnId,
    String? product,
    int? quantity,
    double? price,
    int? stockDelta,
  }) {
    return ReturnItemModel(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pbUpdated: pbUpdated ?? this.pbUpdated,
      created: created ?? this.created,
      updated: updated ?? this.updated,
      returnId: returnId ?? this.returnId,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      stockDelta: stockDelta ?? this.stockDelta,
    );
  }
}
