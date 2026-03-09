// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_manager.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The main Sync Manager that orchestrates bidirectional sync
/// between the local SQLite database and PocketBase.
///
/// It listens to [ConnectivityStatus] and triggers a sync cycle
/// (Upsync → Downsync) whenever connectivity is restored.
///
/// Usage from UI:
/// ```dart
/// // Watch sync state
/// final syncState = ref.watch(syncManagerProvider);
///
/// // Manually trigger sync
/// ref.read(syncManagerProvider.notifier).triggerSync();
/// ```

@ProviderFor(SyncManager)
final syncManagerProvider = SyncManagerProvider._();

/// The main Sync Manager that orchestrates bidirectional sync
/// between the local SQLite database and PocketBase.
///
/// It listens to [ConnectivityStatus] and triggers a sync cycle
/// (Upsync → Downsync) whenever connectivity is restored.
///
/// Usage from UI:
/// ```dart
/// // Watch sync state
/// final syncState = ref.watch(syncManagerProvider);
///
/// // Manually trigger sync
/// ref.read(syncManagerProvider.notifier).triggerSync();
/// ```
final class SyncManagerProvider
    extends $NotifierProvider<SyncManager, SyncState> {
  /// The main Sync Manager that orchestrates bidirectional sync
  /// between the local SQLite database and PocketBase.
  ///
  /// It listens to [ConnectivityStatus] and triggers a sync cycle
  /// (Upsync → Downsync) whenever connectivity is restored.
  ///
  /// Usage from UI:
  /// ```dart
  /// // Watch sync state
  /// final syncState = ref.watch(syncManagerProvider);
  ///
  /// // Manually trigger sync
  /// ref.read(syncManagerProvider.notifier).triggerSync();
  /// ```
  SyncManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncManagerHash();

  @$internal
  @override
  SyncManager create() => SyncManager();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncState>(value),
    );
  }
}

String _$syncManagerHash() => r'9643c3b3994b09871d8ffa41aa261d9321a89504';

/// The main Sync Manager that orchestrates bidirectional sync
/// between the local SQLite database and PocketBase.
///
/// It listens to [ConnectivityStatus] and triggers a sync cycle
/// (Upsync → Downsync) whenever connectivity is restored.
///
/// Usage from UI:
/// ```dart
/// // Watch sync state
/// final syncState = ref.watch(syncManagerProvider);
///
/// // Manually trigger sync
/// ref.read(syncManagerProvider.notifier).triggerSync();
/// ```

abstract class _$SyncManager extends $Notifier<SyncState> {
  SyncState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<SyncState, SyncState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SyncState, SyncState>,
              SyncState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
