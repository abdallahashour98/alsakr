/// Constants and configuration for the sync system.

/// The order in which tables must be synced. Parent tables come before
/// their children so that FK references are valid during upsync.
const List<String> syncTableOrder = [
  'users',
  'suppliers',
  'clients',
  'units',
  'products',
  'expenses',
  'revenues',
  'announcements',
  'sales',
  'sale_items',
  'returns',
  'return_items',
  'receipts',
  'opening_balances',
  'purchases',
  'purchase_items',
  'purchase_returns',
  'purchase_return_items',
  'supplier_payments',
  'delivery_orders',
  'delivery_order_items',
];

/// Maps each PocketBase collection name to its local SQLite table name.
/// In our case they are identical, but this map allows future divergence.
const Map<String, String> collectionToTable = {
  'users': 'users',
  'suppliers': 'suppliers',
  'clients': 'clients',
  'units': 'units',
  'products': 'products',
  'expenses': 'expenses',
  'revenues': 'revenues',
  'announcements': 'announcements',
  'sales': 'sales',
  'sale_items': 'sale_items',
  'returns': 'returns',
  'return_items': 'return_items',
  'receipts': 'receipts',
  'opening_balances': 'opening_balances',
  'purchases': 'purchases',
  'purchase_items': 'purchase_items',
  'purchase_returns': 'purchase_returns',
  'purchase_return_items': 'purchase_return_items',
  'supplier_payments': 'supplier_payments',
  'delivery_orders': 'delivery_orders',
  'delivery_order_items': 'delivery_order_items',
};

/// Foreign-key cascade map.
/// Key = parent table name.
/// Value = list of (child_table, child_fk_column) pairs.
/// When a parent record's `id` changes (offline UUID → server ID),
/// every listed child column must be updated to reflect the new ID.
const Map<String, List<FkRelation>> fkCascadeMap = {
  'clients': [
    FkRelation('sales', 'client'),
    FkRelation('returns', 'client'),
    FkRelation('receipts', 'client'),
    FkRelation('delivery_orders', 'client'),
    FkRelation('opening_balances', 'client'),
  ],
  'suppliers': [
    FkRelation('products', 'supplier'),
    FkRelation('purchases', 'supplier'),
    FkRelation('purchase_returns', 'supplier'),
    FkRelation('supplier_payments', 'supplier'),
  ],
  'products': [
    FkRelation('sale_items', 'product'),
    FkRelation('return_items', 'product'),
    FkRelation('delivery_order_items', 'product'),
    FkRelation('purchase_items', 'product'),
    FkRelation('purchase_return_items', 'product'),
  ],
  'sales': [FkRelation('sale_items', 'sale'), FkRelation('returns', 'sale')],
  'returns': [FkRelation('return_items', 'return_id')],
  'purchases': [FkRelation('purchase_items', 'purchase')],
  'purchase_returns': [FkRelation('purchase_return_items', 'purchase_return')],
  'delivery_orders': [FkRelation('delivery_order_items', 'delivery_order')],
};

/// Tables that contain a `stock_delta` column requiring atomic upsync.
const Set<String> stockDeltaTables = {'sale_items', 'return_items'};

/// Debounce duration before triggering a sync cycle after connectivity change.
const Duration syncDebounce = Duration(seconds: 3);

/// Represents a foreign-key relationship between two tables.
class FkRelation {
  final String childTable;
  final String childColumn;

  const FkRelation(this.childTable, this.childColumn);
}
