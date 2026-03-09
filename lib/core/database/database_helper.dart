import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database_constants.dart';

/// Singleton DatabaseHelper responsible for initialising and providing
/// access to the local SQLite database.
///
/// On mobile (Android/iOS) it uses the default sqflite driver.
/// On desktop (Windows/Linux/macOS) it uses sqflite_common_ffi.
class DatabaseHelper {
  // ---------------------------------------------------------------------------
  // Singleton
  // ---------------------------------------------------------------------------
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _database;

  /// Returns the singleton [Database] instance, creating it if necessary.
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  static bool _ffiInitialized = false;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------
  Future<Database> _initDatabase() async {
    // Desktop platforms need FFI initialisation.
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      if (!_ffiInitialized) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        _ffiInitialized = true;
      }
    }

    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(documentsDir.path, DbConstants.databaseName);

    return await openDatabase(
      dbPath,
      version: DbConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        // Enable foreign keys
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Schema Creation
  // ---------------------------------------------------------------------------
  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // ── sync_meta ────────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE ${DbConstants.tableSyncMeta} (
        collection_name TEXT PRIMARY KEY,
        last_sync_time  TEXT
      )
    ''');

    // ── users ────────────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE ${DbConstants.tableUsers} (
        ${_commonSyncColumns()},
        username              TEXT NOT NULL DEFAULT '',
        email                 TEXT NOT NULL DEFAULT '',
        name                  TEXT NOT NULL DEFAULT '',
        role                  TEXT NOT NULL DEFAULT 'employee',
        // Admin permissions
        allow_manage_permissions INTEGER NOT NULL DEFAULT 0,
        allow_edit_settings   INTEGER NOT NULL DEFAULT 0,
        allow_backup_data     INTEGER NOT NULL DEFAULT 0,

        // Sales permissions
        show_sales            INTEGER NOT NULL DEFAULT 0,
        show_sales_history    INTEGER NOT NULL DEFAULT 0,
        allow_add_orders      INTEGER NOT NULL DEFAULT 0,
        allow_edit_orders     INTEGER NOT NULL DEFAULT 0,
        allow_delete_orders   INTEGER NOT NULL DEFAULT 0,
        allow_add_returns     INTEGER NOT NULL DEFAULT 0,
        allow_change_price    INTEGER NOT NULL DEFAULT 0,
        allow_add_discount    INTEGER NOT NULL DEFAULT 0,

        // Purchases permissions
        show_purchases        INTEGER NOT NULL DEFAULT 0,
        show_purchase_history INTEGER NOT NULL DEFAULT 0,
        allow_add_purchases   INTEGER NOT NULL DEFAULT 0,
        allow_edit_purchases  INTEGER NOT NULL DEFAULT 0,
        allow_delete_purchases INTEGER NOT NULL DEFAULT 0,

        // Stock permissions
        show_stock            INTEGER NOT NULL DEFAULT 0,
        allow_add_products    INTEGER NOT NULL DEFAULT 0,
        allow_edit_products   INTEGER NOT NULL DEFAULT 0,
        allow_delete_products INTEGER NOT NULL DEFAULT 0,
        show_delivery         INTEGER NOT NULL DEFAULT 0,
        allow_add_delivery    INTEGER NOT NULL DEFAULT 0,
        allow_delete_delivery INTEGER NOT NULL DEFAULT 0,
        allow_inventory_settlement INTEGER NOT NULL DEFAULT 0,
        show_buy_price        INTEGER NOT NULL DEFAULT 0,

        // Clients/Suppliers permissions
        show_clients          INTEGER NOT NULL DEFAULT 0,
        show_suppliers        INTEGER NOT NULL DEFAULT 0,
        allow_add_clients     INTEGER NOT NULL DEFAULT 0,
        allow_edit_clients    INTEGER NOT NULL DEFAULT 0,
        allow_delete_clients  INTEGER NOT NULL DEFAULT 0,

        // Financial/Reports permissions
        show_expenses         INTEGER NOT NULL DEFAULT 0,
        allow_add_expenses    INTEGER NOT NULL DEFAULT 0,
        allow_delete_expenses INTEGER NOT NULL DEFAULT 0,
        allow_view_drawer     INTEGER NOT NULL DEFAULT 0,
        allow_add_revenues    INTEGER NOT NULL DEFAULT 0,
        show_reports          INTEGER NOT NULL DEFAULT 0,
        show_returns          INTEGER NOT NULL DEFAULT 0,
        allow_delete_returns  INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // ── clients ──────────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE ${DbConstants.tableClients} (
        ${_commonSyncColumns()},
        name        TEXT NOT NULL DEFAULT '',
        phone       TEXT NOT NULL DEFAULT '',
        address     TEXT NOT NULL DEFAULT '',
        balance     REAL NOT NULL DEFAULT 0.0,
        is_deleted  INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // ── suppliers ────────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE ${DbConstants.tableSuppliers} (
        ${_commonSyncColumns()},
        name          TEXT NOT NULL DEFAULT '',
        phone         TEXT NOT NULL DEFAULT '',
        address       TEXT NOT NULL DEFAULT '',
        contactPerson TEXT NOT NULL DEFAULT '',
        balance       REAL NOT NULL DEFAULT 0.0,
        is_deleted    INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // ── products ─────────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE ${DbConstants.tableProducts} (
        ${_commonSyncColumns()},
        name        TEXT NOT NULL DEFAULT '',
        buyPrice    REAL NOT NULL DEFAULT 0.0,
        sellPrice   REAL NOT NULL DEFAULT 0.0,
        stock       INTEGER NOT NULL DEFAULT 0,
        unit        TEXT NOT NULL DEFAULT '',
        supplier    TEXT NOT NULL DEFAULT '',
        image       TEXT NOT NULL DEFAULT '',
        is_deleted  INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // ── units ────────────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE ${DbConstants.tableUnits} (
        ${_commonSyncColumns()},
        name TEXT NOT NULL DEFAULT ''
      )
    ''');

    // ── sales ────────────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE ${DbConstants.tableSales} (
        ${_commonSyncColumns()},
        client          TEXT NOT NULL DEFAULT '',
        totalAmount     REAL NOT NULL DEFAULT 0.0,
        discount        REAL NOT NULL DEFAULT 0.0,
        taxAmount       REAL NOT NULL DEFAULT 0.0,
        whtAmount       REAL NOT NULL DEFAULT 0.0,
        netAmount       REAL NOT NULL DEFAULT 0.0,
        paymentType     TEXT NOT NULL DEFAULT 'cash',
        date            TEXT NOT NULL DEFAULT '',
        referenceNumber TEXT NOT NULL DEFAULT '',
        is_deleted      INTEGER NOT NULL DEFAULT 0,
        is_complete     INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // ── sale_items ────────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE ${DbConstants.tableSaleItems} (
        ${_commonSyncColumns()},
        sale        TEXT NOT NULL DEFAULT '',
        product     TEXT NOT NULL DEFAULT '',
        quantity    INTEGER NOT NULL DEFAULT 0,
        price       REAL NOT NULL DEFAULT 0.0,
        stock_delta INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // ── returns ──────────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE ${DbConstants.tableReturns} (
        ${_commonSyncColumns()},
        sale        TEXT NOT NULL DEFAULT '',
        client      TEXT NOT NULL DEFAULT '',
        totalAmount REAL NOT NULL DEFAULT 0.0,
        paidAmount  REAL NOT NULL DEFAULT 0.0,
        discount    REAL NOT NULL DEFAULT 0.0,
        date        TEXT NOT NULL DEFAULT '',
        notes       TEXT NOT NULL DEFAULT '',
        is_complete INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // ── return_items ─────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE ${DbConstants.tableReturnItems} (
        ${_commonSyncColumns()},
        return_id   TEXT NOT NULL DEFAULT '',
        product     TEXT NOT NULL DEFAULT '',
        quantity    INTEGER NOT NULL DEFAULT 0,
        price       REAL NOT NULL DEFAULT 0.0,
        stock_delta INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // ── receipts ─────────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE ${DbConstants.tableReceipts} (
        ${_commonSyncColumns()},
        client  TEXT NOT NULL DEFAULT '',
        amount  REAL NOT NULL DEFAULT 0.0,
        notes   TEXT NOT NULL DEFAULT '',
        date    TEXT NOT NULL DEFAULT '',
        method  TEXT NOT NULL DEFAULT 'cash'
      )
    ''');

    // ── delivery_orders ──────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE ${DbConstants.tableDeliveryOrders} (
        ${_commonSyncColumns()},
        client            TEXT NOT NULL DEFAULT '',
        supplyOrderNumber TEXT NOT NULL DEFAULT '',
        manualNo          TEXT NOT NULL DEFAULT '',
        address           TEXT NOT NULL DEFAULT '',
        date              TEXT NOT NULL DEFAULT '',
        notes             TEXT NOT NULL DEFAULT '',
        is_complete       INTEGER NOT NULL DEFAULT 0,
        isLocked          INTEGER NOT NULL DEFAULT 0,
        image             TEXT NOT NULL DEFAULT '',
        is_deleted        INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // ── delivery_order_items ─────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE ${DbConstants.tableDeliveryOrderItems} (
        ${_commonSyncColumns()},
        delivery_order      TEXT NOT NULL DEFAULT '',
        product             TEXT NOT NULL DEFAULT '',
        quantity            INTEGER NOT NULL DEFAULT 0,
        description         TEXT NOT NULL DEFAULT '',
        relatedSupplyOrder  TEXT NOT NULL DEFAULT ''
      )
    ''');

    // ── purchases ────────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE ${DbConstants.tablePurchases} (
        ${_commonSyncColumns()},
        supplier    TEXT NOT NULL DEFAULT '',
        totalAmount REAL NOT NULL DEFAULT 0.0,
        discount    REAL NOT NULL DEFAULT 0.0,
        paymentType TEXT NOT NULL DEFAULT 'cash',
        date        TEXT NOT NULL DEFAULT '',
        notes       TEXT NOT NULL DEFAULT '',
        is_deleted  INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // ── purchase_items ───────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE ${DbConstants.tablePurchaseItems} (
        ${_commonSyncColumns()},
        purchase    TEXT NOT NULL DEFAULT '',
        product     TEXT NOT NULL DEFAULT '',
        quantity    INTEGER NOT NULL DEFAULT 0,
        costPrice   REAL NOT NULL DEFAULT 0.0
      )
    ''');

    // ── purchase_returns ─────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE ${DbConstants.tablePurchaseReturns} (
        ${_commonSyncColumns()},
        supplier    TEXT NOT NULL DEFAULT '',
        purchase    TEXT NOT NULL DEFAULT '',
        totalAmount REAL NOT NULL DEFAULT 0.0,
        paidAmount  REAL NOT NULL DEFAULT 0.0,
        date        TEXT NOT NULL DEFAULT ''
      )
    ''');

    // ── purchase_return_items ────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE ${DbConstants.tablePurchaseReturnItems} (
        ${_commonSyncColumns()},
        purchase_return TEXT NOT NULL DEFAULT '',
        product         TEXT NOT NULL DEFAULT '',
        quantity        INTEGER NOT NULL DEFAULT 0,
        price           REAL NOT NULL DEFAULT 0.0
      )
    ''');

    // ── supplier_payments ────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE ${DbConstants.tableSupplierPayments} (
        ${_commonSyncColumns()},
        supplier TEXT NOT NULL DEFAULT '',
        amount   REAL NOT NULL DEFAULT 0.0,
        date     TEXT NOT NULL DEFAULT '',
        notes    TEXT NOT NULL DEFAULT ''
      )
    ''');

    // ── expenses ─────────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE ${DbConstants.tableExpenses} (
        ${_commonSyncColumns()},
        description TEXT NOT NULL DEFAULT '',
        amount      REAL NOT NULL DEFAULT 0.0,
        category    TEXT NOT NULL DEFAULT '',
        date        TEXT NOT NULL DEFAULT '',
        is_deleted  INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // ── revenues ─────────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE ${DbConstants.tableRevenues} (
        ${_commonSyncColumns()},
        description TEXT NOT NULL DEFAULT '',
        amount      REAL NOT NULL DEFAULT 0.0,
        category    TEXT NOT NULL DEFAULT '',
        date        TEXT NOT NULL DEFAULT '',
        is_deleted  INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // ── announcements ────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE ${DbConstants.tableAnnouncements} (
        ${_commonSyncColumns()},
        title        TEXT NOT NULL DEFAULT '',
        content      TEXT NOT NULL DEFAULT '',
        priority     TEXT NOT NULL DEFAULT 'normal',
        user         TEXT NOT NULL DEFAULT '',
        target_users TEXT NOT NULL DEFAULT '',
        seen_by      TEXT NOT NULL DEFAULT '',
        image        TEXT NOT NULL DEFAULT ''
      )
    ''');

    // ── opening_balances ─────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE ${DbConstants.tableOpeningBalances} (
        ${_commonSyncColumns()},
        client TEXT NOT NULL DEFAULT '',
        amount REAL NOT NULL DEFAULT 0.0,
        date   TEXT NOT NULL DEFAULT '',
        notes  TEXT NOT NULL DEFAULT ''
      )
    ''');

    // ── settings ─────────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE ${DbConstants.tableSettings} (
        ${_commonSyncColumns()},
        collectionId    TEXT NOT NULL DEFAULT '',
        collectionName  TEXT NOT NULL DEFAULT '',
        company_name    TEXT NOT NULL DEFAULT '',
        address         TEXT NOT NULL DEFAULT '',
        phone           TEXT NOT NULL DEFAULT '',
        mobile          TEXT NOT NULL DEFAULT '',
        website         TEXT NOT NULL DEFAULT '',
        email           TEXT NOT NULL DEFAULT ''
      )
    ''');

    // ── Indexes (Performance Optimization) ───────────────────────────────────
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_sale_items_sale ON ${DbConstants.tableSaleItems}(sale)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_sale_items_product ON ${DbConstants.tableSaleItems}(product)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_return_items_return_id ON ${DbConstants.tableReturnItems}(return_id)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_return_items_product ON ${DbConstants.tableReturnItems}(product)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_client ON ${DbConstants.tableSales}(client)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_returns_sale ON ${DbConstants.tableReturns}(sale)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchase_items_purchase ON ${DbConstants.tablePurchaseItems}(purchase)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchase_items_product ON ${DbConstants.tablePurchaseItems}(product)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_delivery_order_items_order ON ${DbConstants.tableDeliveryOrderItems}(delivery_order)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_date ON ${DbConstants.tableSales}(date)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchases_date ON ${DbConstants.tablePurchases}(date)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_expenses_date ON ${DbConstants.tableExpenses}(date)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_revenues_date ON ${DbConstants.tableRevenues}(date)',
    );

    await batch.commit(noResult: true);
  }

  // ---------------------------------------------------------------------------
  // Schema Migration
  // ---------------------------------------------------------------------------
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    final batch = db.batch();
    if (oldVersion < 2) {
      batch.execute(
        'ALTER TABLE ${DbConstants.tableSuppliers} ADD COLUMN contactPerson TEXT NOT NULL DEFAULT ""',
      );
      batch.execute(
        'ALTER TABLE ${DbConstants.tableSuppliers} ADD COLUMN balance REAL NOT NULL DEFAULT 0.0',
      );
      batch.execute(
        'ALTER TABLE ${DbConstants.tableSuppliers} ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0',
      );
    }

    // Migration 2 -> 3
    if (oldVersion < 3) {
      await db.delete(DbConstants.tableSyncMeta);
    }

    // Migration 3 -> 4: Add purchase_items and purchase_return_items tables
    if (oldVersion < 4) {
      batch.execute('''
        CREATE TABLE IF NOT EXISTS ${DbConstants.tablePurchaseItems} (
          ${_commonSyncColumns()},
          purchase    TEXT NOT NULL DEFAULT '',
          product     TEXT NOT NULL DEFAULT '',
          quantity    INTEGER NOT NULL DEFAULT 0,
          costPrice   REAL NOT NULL DEFAULT 0.0
        )
      ''');
      batch.execute('''
        CREATE TABLE IF NOT EXISTS ${DbConstants.tablePurchaseReturnItems} (
          ${_commonSyncColumns()},
          purchase_return TEXT NOT NULL DEFAULT '',
          product         TEXT NOT NULL DEFAULT '',
          quantity        INTEGER NOT NULL DEFAULT 0,
          price           REAL NOT NULL DEFAULT 0.0
        )
      ''');
      // Clear sync_meta to force re-sync of purchase data with items
      await db.delete(DbConstants.tableSyncMeta);
    }

    // Migration 4 -> 5: Add paidAmount column to returns and purchase_returns
    if (oldVersion < 5) {
      batch.execute(
        'ALTER TABLE ${DbConstants.tableReturns} ADD COLUMN paidAmount REAL NOT NULL DEFAULT 0.0',
      );
      batch.execute(
        'ALTER TABLE ${DbConstants.tablePurchaseReturns} ADD COLUMN paidAmount REAL NOT NULL DEFAULT 0.0',
      );
      // Also add purchase column to purchase_returns if upgrading from < 5
      try {
        batch.execute(
          'ALTER TABLE ${DbConstants.tablePurchaseReturns} ADD COLUMN purchase TEXT NOT NULL DEFAULT ""',
        );
      } catch (_) {
        // Column may already exist
      }
    }

    // Migration 5 -> 6: Add paymentType to purchases
    if (oldVersion < 6) {
      try {
        batch.execute(
          'ALTER TABLE ${DbConstants.tablePurchases} ADD COLUMN paymentType TEXT NOT NULL DEFAULT "cash"',
        );
      } catch (_) {
        // Column may already exist
      }
    }

    // Migration 6 -> 7: Add revenues table
    if (oldVersion < 7) {
      batch.execute('''
        CREATE TABLE IF NOT EXISTS ${DbConstants.tableRevenues} (
          ${_commonSyncColumns()},
          description TEXT NOT NULL DEFAULT '',
          amount      REAL NOT NULL DEFAULT 0.0,
          category    TEXT NOT NULL DEFAULT '',
          date        TEXT NOT NULL DEFAULT '',
          is_deleted  INTEGER NOT NULL DEFAULT 0
        )
      ''');
      batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_revenues_date ON ${DbConstants.tableRevenues}(date)',
      );
    }

    // Migration 7 -> 8: Add settings table
    if (oldVersion < 8) {
      batch.execute('''
        CREATE TABLE IF NOT EXISTS ${DbConstants.tableSettings} (
          ${_commonSyncColumns()},
          collectionId    TEXT NOT NULL DEFAULT '',
          collectionName  TEXT NOT NULL DEFAULT '',
          company_name    TEXT NOT NULL DEFAULT '',
          address         TEXT NOT NULL DEFAULT '',
          phone           TEXT NOT NULL DEFAULT '',
          mobile          TEXT NOT NULL DEFAULT '',
          website         TEXT NOT NULL DEFAULT '',
          email           TEXT NOT NULL DEFAULT ''
        )
      ''');
    }

    // Migration 8 -> 9: Add advanced user permissions
    if (oldVersion < 9) {
      await batch.commit(noResult: true); // Commit previous batches first
      final newColumns = [
        'allow_manage_permissions',
        'allow_edit_settings',
        'allow_backup_data',
        'show_sales',
        'show_sales_history',
        'allow_add_orders',
        'allow_edit_orders',
        'allow_delete_orders',
        'allow_add_returns',
        'allow_change_price',
        'allow_add_discount',
        'show_purchases',
        'show_purchase_history',
        'allow_add_purchases',
        'allow_edit_purchases',
        'allow_delete_purchases',
        'show_stock',
        'allow_add_products',
        'allow_edit_products',
        'allow_delete_products',
        'show_delivery',
        'allow_add_delivery',
        'allow_delete_delivery',
        'allow_inventory_settlement',
        'show_buy_price',
        'show_clients',
        'show_suppliers',
        'allow_add_clients',
        'allow_edit_clients',
        'allow_delete_clients',
        'show_expenses',
        'allow_add_expenses',
        'allow_delete_expenses',
        'allow_view_drawer',
        'allow_add_revenues',
        'show_reports',
        'show_returns',
        'allow_delete_returns',
      ];
      for (final col in newColumns) {
        try {
          await db.execute(
            'ALTER TABLE ${DbConstants.tableUsers} ADD COLUMN $col INTEGER NOT NULL DEFAULT 0',
          );
        } catch (_) {}
      }
      return; // Return early since batch is already committed
    }

    // Migration 9 -> 10: Retry adding advanced user permissions
    // This handles users who upgraded to version 9 where the schema didn't fully apply
    if (oldVersion < 10) {
      await batch.commit(noResult: true); // Commit previous batches first
      final newColumns = [
        'allow_manage_permissions',
        'allow_edit_settings',
        'allow_backup_data',
        'show_sales',
        'show_sales_history',
        'allow_add_orders',
        'allow_edit_orders',
        'allow_delete_orders',
        'allow_add_returns',
        'allow_change_price',
        'allow_add_discount',
        'show_purchases',
        'show_purchase_history',
        'allow_add_purchases',
        'allow_edit_purchases',
        'allow_delete_purchases',
        'show_stock',
        'allow_add_products',
        'allow_edit_products',
        'allow_delete_products',
        'show_delivery',
        'allow_add_delivery',
        'allow_delete_delivery',
        'allow_inventory_settlement',
        'show_buy_price',
        'show_clients',
        'show_suppliers',
        'allow_add_clients',
        'allow_edit_clients',
        'allow_delete_clients',
        'show_expenses',
        'allow_add_expenses',
        'allow_delete_expenses',
        'allow_view_drawer',
        'allow_add_revenues',
        'show_reports',
        'show_returns',
        'allow_delete_returns',
      ];
      for (final col in newColumns) {
        try {
          await db.execute(
            'ALTER TABLE ${DbConstants.tableUsers} ADD COLUMN $col INTEGER NOT NULL DEFAULT 0',
          );
        } catch (_) {}
      }
      return; // Return early since batch is already committed
    }

    await batch.commit(noResult: true);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns the common sync columns shared by every table.
  static String _commonSyncColumns() {
    return '''
        ${DbConstants.colId}            TEXT PRIMARY KEY,
        ${DbConstants.colLocalId}       TEXT UNIQUE,
        ${DbConstants.colSyncStatus}    TEXT NOT NULL DEFAULT '${SyncStatus.synced}',
        ${DbConstants.colLastSyncedAt}  TEXT,
        ${DbConstants.colPbUpdated}     TEXT,
        ${DbConstants.colCreated}       TEXT,
        ${DbConstants.colUpdated}       TEXT
    ''';
  }

  /// Close the database (e.g. for testing or cleanup).
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
