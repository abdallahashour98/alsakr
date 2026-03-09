import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/database/models/sync_fields_mixin.dart';

/// A line item in a sale. The [stockDelta] field captures the quantity change
/// for atomic inventory updates during upsync (e.g., -3 means 3 items sold).
class SaleItemModel with SyncFieldsMixin {
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
  final String product; // FK → products.id
  final int quantity;
  final double price;
  final int stockDelta; // Negative for sales (e.g., -3)

  SaleItemModel({
    required this.id,
    required this.localId,
    this.syncStatus = SyncStatus.synced,
    this.lastSyncedAt,
    this.pbUpdated,
    this.created,
    this.updated,
    required this.sale,
    required this.product,
    this.quantity = 0,
    this.price = 0.0,
    this.stockDelta = 0,
  });

  factory SaleItemModel.fromMap(Map<String, dynamic> map) {
    return SaleItemModel(
      id: map[DbConstants.colId] ?? '',
      localId: map[DbConstants.colLocalId] ?? '',
      syncStatus: map[DbConstants.colSyncStatus] ?? SyncStatus.synced,
      lastSyncedAt: map[DbConstants.colLastSyncedAt],
      pbUpdated: map[DbConstants.colPbUpdated],
      created: map[DbConstants.colCreated],
      updated: map[DbConstants.colUpdated],
      sale: map['sale'] ?? '',
      product: map['product'] ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      stockDelta: (map['stock_delta'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    ...syncFieldsToMap(),
    'sale': sale,
    'product': product,
    'quantity': quantity,
    'price': price,
    'stock_delta': stockDelta,
  };

  Map<String, dynamic> toServerMap() => {
    'sale': sale,
    'product': product,
    'quantity': quantity,
    'price': price,
  };

  SaleItemModel copyWith({
    String? id,
    String? localId,
    String? syncStatus,
    String? lastSyncedAt,
    String? pbUpdated,
    String? created,
    String? updated,
    String? sale,
    String? product,
    int? quantity,
    double? price,
    int? stockDelta,
  }) {
    return SaleItemModel(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pbUpdated: pbUpdated ?? this.pbUpdated,
      created: created ?? this.created,
      updated: updated ?? this.updated,
      sale: sale ?? this.sale,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      stockDelta: stockDelta ?? this.stockDelta,
    );
  }
}
