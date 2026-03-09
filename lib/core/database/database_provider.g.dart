// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Riverpod provider that exposes the local SQLite [Database] instance.
/// Uses keepAlive to ensure the database connection persists across the app.

@ProviderFor(localDatabase)
final localDatabaseProvider = LocalDatabaseProvider._();

/// Riverpod provider that exposes the local SQLite [Database] instance.
/// Uses keepAlive to ensure the database connection persists across the app.

final class LocalDatabaseProvider
    extends
        $FunctionalProvider<AsyncValue<Database>, Database, FutureOr<Database>>
    with $FutureModifier<Database>, $FutureProvider<Database> {
  /// Riverpod provider that exposes the local SQLite [Database] instance.
  /// Uses keepAlive to ensure the database connection persists across the app.
  LocalDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localDatabaseHash();

  @$internal
  @override
  $FutureProviderElement<Database> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Database> create(Ref ref) {
    return localDatabase(ref);
  }
}

String _$localDatabaseHash() => r'9386f4d7238b657c46027cad5819741f50b0ab25';
