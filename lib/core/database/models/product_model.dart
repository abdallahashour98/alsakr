import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/database/models/sync_fields_mixin.dart';

class ProductModel with SyncFieldsMixin {
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

  final String name;
  final double buyPrice;
  final double sellPrice;
  final int stock;
  final String unit;
  final String supplier; // FK → suppliers.id
  final String image;
  final bool isDeleted;

  ProductModel({
    required this.id,
    required this.localId,
    this.syncStatus = SyncStatus.synced,
    this.lastSyncedAt,
    this.pbUpdated,
    this.created,
    this.updated,
    required this.name,
    this.buyPrice = 0.0,
    this.sellPrice = 0.0,
    this.stock = 0,
    this.unit = '',
    this.supplier = '',
    this.image = '',
    this.isDeleted = false,
  });

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map[DbConstants.colId] ?? '',
      localId: map[DbConstants.colLocalId] ?? '',
      syncStatus: map[DbConstants.colSyncStatus] ?? SyncStatus.synced,
      lastSyncedAt: map[DbConstants.colLastSyncedAt],
      pbUpdated: map[DbConstants.colPbUpdated],
      created: map[DbConstants.colCreated],
      updated: map[DbConstants.colUpdated],
      name: map['name'] ?? '',
      buyPrice: (map['buyPrice'] as num?)?.toDouble() ?? 0.0,
      sellPrice: (map['sellPrice'] as num?)?.toDouble() ?? 0.0,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      unit: map['unit'] ?? '',
      supplier: map['supplier'] ?? '',
      image: map['image'] ?? '',
      isDeleted: (map['is_deleted'] is int)
          ? map['is_deleted'] == 1
          : (map['is_deleted'] ?? false),
    );
  }

  Map<String, dynamic> toMap() => {
    ...syncFieldsToMap(),
    'name': name,
    'buyPrice': buyPrice,
    'sellPrice': sellPrice,
    'stock': stock,
    'unit': unit,
    'supplier': supplier,
    'image': image,
    'is_deleted': isDeleted ? 1 : 0,
  };

  Map<String, dynamic> toServerMap() => {
    'name': name,
    'buyPrice': buyPrice,
    'sellPrice': sellPrice,
    'stock': stock,
    'unit': unit,
    'supplier': supplier,
    'is_deleted': isDeleted,
  };

  ProductModel copyWith({
    String? id,
    String? localId,
    String? syncStatus,
    String? lastSyncedAt,
    String? pbUpdated,
    String? created,
    String? updated,
    String? name,
    double? buyPrice,
    double? sellPrice,
    int? stock,
    String? unit,
    String? supplier,
    String? image,
    bool? isDeleted,
  }) {
    return ProductModel(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pbUpdated: pbUpdated ?? this.pbUpdated,
      created: created ?? this.created,
      updated: updated ?? this.updated,
      name: name ?? this.name,
      buyPrice: buyPrice ?? this.buyPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      stock: stock ?? this.stock,
      unit: unit ?? this.unit,
      supplier: supplier ?? this.supplier,
      image: image ?? this.image,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
