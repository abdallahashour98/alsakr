// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trash_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Trash controller — queries the local DB for soft-deleted items.

@ProviderFor(TrashController)
final trashControllerProvider = TrashControllerProvider._();

/// Trash controller — queries the local DB for soft-deleted items.
final class TrashControllerProvider
    extends $AsyncNotifierProvider<TrashController, void> {
  /// Trash controller — queries the local DB for soft-deleted items.
  TrashControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trashControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trashControllerHash();

  @$internal
  @override
  TrashController create() => TrashController();
}

String _$trashControllerHash() => r'ee80a1f60120dfc2188507d49ebcc65738cd0e83';

/// Trash controller — queries the local DB for soft-deleted items.

abstract class _$TrashController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
