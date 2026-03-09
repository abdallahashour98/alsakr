class UserModel {
  final String id;
  final String username;
  final String email;
  final String name;
  final String role;

  // Permissions
  final bool allowAddClients;
  final bool allowEditClients;
  final bool allowDeleteClients;
  final bool allowAddPurchases;
  final bool allowAddOrders;

  // Advanced Permissions
  final bool allowChangePrice;
  final bool allowAddDiscount;
  final bool showBuyPrice;
  final bool allowViewDrawer;
  final bool allowAddRevenues;
  final bool allowInventorySettlement;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.name,
    required this.role,
    this.allowAddClients = false,
    this.allowEditClients = false,
    this.allowDeleteClients = false,
    this.allowAddPurchases = false,
    this.allowAddOrders = false,
    this.allowChangePrice = false,
    this.allowAddDiscount = false,
    this.showBuyPrice = false,
    this.allowViewDrawer = false,
    this.allowAddRevenues = false,
    this.allowInventorySettlement = false,
  });

  bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value == 1) return true;
    if (value == 0) return false;
    if (value == 'true') return true;
    if (value == 'false') return false;
    if (value is bool) return value;
    return false;
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    final model = UserModel(
      id: docId,
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? 'employee',
    );
    return UserModel(
      id: docId,
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? 'employee',
      allowAddClients: model._parseBool(map['allow_add_clients']),
      allowEditClients: model._parseBool(map['allow_edit_clients']),
      allowDeleteClients: model._parseBool(map['allow_delete_clients']),
      allowAddPurchases: model._parseBool(map['allow_add_purchases']),
      allowAddOrders: model._parseBool(map['allow_add_orders']),
      allowChangePrice: model._parseBool(map['allow_change_price']),
      allowAddDiscount: model._parseBool(map['allow_add_discount']),
      showBuyPrice: model._parseBool(map['show_buy_price']),
      allowViewDrawer: model._parseBool(map['allow_view_drawer']),
      allowAddRevenues: model._parseBool(map['allow_add_revenues']),
      allowInventorySettlement: model._parseBool(
        map['allow_inventory_settlement'],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'email': email,
      'name': name,
      'role': role,
      'allow_add_clients': allowAddClients ? 1 : 0,
      'allow_edit_clients': allowEditClients ? 1 : 0,
      'allow_delete_clients': allowDeleteClients ? 1 : 0,
      'allow_add_purchases': allowAddPurchases ? 1 : 0,
      'allow_add_orders': allowAddOrders ? 1 : 0,
      'allow_change_price': allowChangePrice ? 1 : 0,
      'allow_add_discount': allowAddDiscount ? 1 : 0,
      'show_buy_price': showBuyPrice ? 1 : 0,
      'allow_view_drawer': allowViewDrawer ? 1 : 0,
      'allow_add_revenues': allowAddRevenues ? 1 : 0,
      'allow_inventory_settlement': allowInventorySettlement ? 1 : 0,
    };
  }

  UserModel copyWith({
    String? id,
    String? username,
    String? email,
    String? name,
    String? role,
    bool? allowAddClients,
    bool? allowEditClients,
    bool? allowDeleteClients,
    bool? allowAddPurchases,
    bool? allowAddOrders,
    bool? allowChangePrice,
    bool? allowAddDiscount,
    bool? showBuyPrice,
    bool? allowViewDrawer,
    bool? allowAddRevenues,
    bool? allowInventorySettlement,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      allowAddClients: allowAddClients ?? this.allowAddClients,
      allowEditClients: allowEditClients ?? this.allowEditClients,
      allowDeleteClients: allowDeleteClients ?? this.allowDeleteClients,
      allowAddPurchases: allowAddPurchases ?? this.allowAddPurchases,
      allowAddOrders: allowAddOrders ?? this.allowAddOrders,
      allowChangePrice: allowChangePrice ?? this.allowChangePrice,
      allowAddDiscount: allowAddDiscount ?? this.allowAddDiscount,
      showBuyPrice: showBuyPrice ?? this.showBuyPrice,
      allowViewDrawer: allowViewDrawer ?? this.allowViewDrawer,
      allowAddRevenues: allowAddRevenues ?? this.allowAddRevenues,
      allowInventorySettlement:
          allowInventorySettlement ?? this.allowInventorySettlement,
    );
  }
}
