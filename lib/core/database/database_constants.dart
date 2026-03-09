/// Constants for the local SQLite database used in the offline-first architecture.
class DbConstants {
  // Database
  static const String databaseName = 'al_sakr_local.db';
  static const int databaseVersion = 10;

  // Table Names
  static const String tableClients = 'clients';
  static const String tableProducts = 'products';
  static const String tableSuppliers = 'suppliers';
  static const String tableSales = 'sales';
  static const String tableSaleItems = 'sale_items';
  static const String tableReturns = 'returns';
  static const String tableReturnItems = 'return_items';
  static const String tableReceipts = 'receipts';
  static const String tableDeliveryOrders = 'delivery_orders';
  static const String tableDeliveryOrderItems = 'delivery_order_items';
  static const String tablePurchases = 'purchases';
  static const String tablePurchaseItems = 'purchase_items';
  static const String tablePurchaseReturns = 'purchase_returns';
  static const String tablePurchaseReturnItems = 'purchase_return_items';
  static const String tableSupplierPayments = 'supplier_payments';
  static const String tableExpenses = 'expenses';
  static const String tableRevenues = 'revenues';
  static const String tableAnnouncements = 'announcements';
  static const String tableOpeningBalances = 'opening_balances';
  static const String tableUnits = 'units';
  static const String tableUsers = 'users';
  static const String tableSettings = 'settings';
  static const String tableSyncMeta = 'sync_meta';

  // Common Column Names
  static const String colId = 'id';
  static const String colLocalId = 'local_id';
  static const String colSyncStatus = 'sync_status';
  static const String colLastSyncedAt = 'last_synced_at';
  static const String colPbUpdated = 'pb_updated';
  static const String colCreated = 'created';
  static const String colUpdated = 'updated';

  // User Permission Columns
  static const String colAllowChangePrice = 'allow_change_price';
  static const String colAllowAddDiscount = 'allow_add_discount';
  static const String colShowBuyPrice = 'show_buy_price';
  static const String colAllowViewDrawer = 'allow_view_drawer';
  static const String colAllowAddRevenues = 'allow_add_revenues';
  static const String colAllowInventorySettlement =
      'allow_inventory_settlement';
  static const String colAllowEditClients = 'allow_edit_clients';
}

/// Sync status values for tracking local changes.
class SyncStatus {
  static const String synced = 'synced';
  static const String pendingCreate = 'pending_create';
  static const String pendingUpdate = 'pending_update';
  static const String pendingDelete = 'pending_delete';
}
