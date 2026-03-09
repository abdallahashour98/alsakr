class TransactionItemModel {
  final String id;
  final String productId;
  final String productName;
  final int quantity;
  final double price; // Normalized from price / costPrice

  double get total => quantity * price;

  TransactionItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
  });

  /// Factory for parsing Sale Items (uses 'price')
  factory TransactionItemModel.fromSaleItem(Map<String, dynamic> map) {
    return TransactionItemModel(
      id: map['id']?.toString() ?? '',
      productId: map['product']?.toString() ?? '',
      productName: map['productName']?.toString() ?? 'صنف غير معروف',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Factory for parsing Purchase Items (uses 'costPrice')
  factory TransactionItemModel.fromPurchaseItem(Map<String, dynamic> map) {
    return TransactionItemModel(
      id: map['id']?.toString() ?? '',
      productId: map['product']?.toString() ?? '',
      productName: map['productName']?.toString() ?? 'صنف غير معروف',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      price: (map['costPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Factory for parsing Return Items (uses 'price')
  factory TransactionItemModel.fromReturnItem(Map<String, dynamic> map) {
    return TransactionItemModel(
      id: map['id']?.toString() ?? '',
      productId: map['product']?.toString() ?? '',
      productName: map['productName']?.toString() ?? 'صنف غير معروف',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Factory for parsing Purchase Return Items (uses 'price')
  factory TransactionItemModel.fromPurchaseReturnItem(
    Map<String, dynamic> map,
  ) {
    return TransactionItemModel(
      id: map['id']?.toString() ?? '',
      productId: map['product']?.toString() ?? '',
      productName: map['productName']?.toString() ?? 'صنف غير معروف',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Convert to Map for PDF Services
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product': productId,
      'productName': productName,
      'quantity': quantity,
      'price': price,
    };
  }
}
