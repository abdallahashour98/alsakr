import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/database/models/sync_fields_mixin.dart';

class DeliveryOrderItemModel with SyncFieldsMixin {
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

  final String deliveryOrder; // FK → delivery_orders.id
  final String product; // FK → products.id
  final int quantity;
  final String description;
  final String relatedSupplyOrder;

  DeliveryOrderItemModel({
    required this.id,
    required this.localId,
    this.syncStatus = SyncStatus.synced,
    this.lastSyncedAt,
    this.pbUpdated,
    this.created,
    this.updated,
    required this.deliveryOrder,
    required this.product,
    this.quantity = 0,
    this.description = '',
    this.relatedSupplyOrder = '',
  });

  factory DeliveryOrderItemModel.fromMap(Map<String, dynamic> map) {
    return DeliveryOrderItemModel(
      id: map[DbConstants.colId] ?? '',
      localId: map[DbConstants.colLocalId] ?? '',
      syncStatus: map[DbConstants.colSyncStatus] ?? SyncStatus.synced,
      lastSyncedAt: map[DbConstants.colLastSyncedAt],
      pbUpdated: map[DbConstants.colPbUpdated],
      created: map[DbConstants.colCreated],
      updated: map[DbConstants.colUpdated],
      deliveryOrder: map['delivery_order'] ?? '',
      product: map['product'] ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      description: map['description'] ?? '',
      relatedSupplyOrder: map['relatedSupplyOrder'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    ...syncFieldsToMap(),
    'delivery_order': deliveryOrder,
    'product': product,
    'quantity': quantity,
    'description': description,
    'relatedSupplyOrder': relatedSupplyOrder,
  };

  Map<String, dynamic> toServerMap() => {
    'delivery_order': deliveryOrder,
    'product': product,
    'quantity': quantity,
    'description': description,
    'relatedSupplyOrder': relatedSupplyOrder,
  };

  DeliveryOrderItemModel copyWith({
    String? id,
    String? localId,
    String? syncStatus,
    String? lastSyncedAt,
    String? pbUpdated,
    String? created,
    String? updated,
    String? deliveryOrder,
    String? product,
    int? quantity,
    String? description,
    String? relatedSupplyOrder,
  }) {
    return DeliveryOrderItemModel(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pbUpdated: pbUpdated ?? this.pbUpdated,
      created: created ?? this.created,
      updated: updated ?? this.updated,
      deliveryOrder: deliveryOrder ?? this.deliveryOrder,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      description: description ?? this.description,
      relatedSupplyOrder: relatedSupplyOrder ?? this.relatedSupplyOrder,
    );
  }
}
