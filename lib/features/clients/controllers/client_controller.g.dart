// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Client controller that reads ONLY from the local SQLite database.
///
/// All mutations (create, update, delete) write to the local DB
/// with the appropriate `sync_status`. The [SyncManager] handles
/// pushing those changes to PocketBase in the background.

@ProviderFor(ClientController)
final clientControllerProvider = ClientControllerProvider._();

/// Client controller that reads ONLY from the local SQLite database.
///
/// All mutations (create, update, delete) write to the local DB
/// with the appropriate `sync_status`. The [SyncManager] handles
/// pushing those changes to PocketBase in the background.
final class ClientControllerProvider
    extends
        $AsyncNotifierProvider<ClientController, List<Map<String, dynamic>>> {
  /// Client controller that reads ONLY from the local SQLite database.
  ///
  /// All mutations (create, update, delete) write to the local DB
  /// with the appropriate `sync_status`. The [SyncManager] handles
  /// pushing those changes to PocketBase in the background.
  ClientControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clientControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clientControllerHash();

  @$internal
  @override
  ClientController create() => ClientController();
}

String _$clientControllerHash() => r'ab69c2febcf1a200123938158d7c28f2a2cb1586';

/// Client controller that reads ONLY from the local SQLite database.
///
/// All mutations (create, update, delete) write to the local DB
/// with the appropriate `sync_status`. The [SyncManager] handles
/// pushing those changes to PocketBase in the background.

abstract class _$ClientController
    extends $AsyncNotifier<List<Map<String, dynamic>>> {
  FutureOr<List<Map<String, dynamic>>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<Map<String, dynamic>>>,
              List<Map<String, dynamic>>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<Map<String, dynamic>>>,
                List<Map<String, dynamic>>
              >,
              AsyncValue<List<Map<String, dynamic>>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
