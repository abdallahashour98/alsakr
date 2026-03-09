// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'store_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(StoreController)
final storeControllerProvider = StoreControllerProvider._();

final class StoreControllerProvider
    extends
        $AsyncNotifierProvider<StoreController, List<Map<String, dynamic>>> {
  StoreControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storeControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storeControllerHash();

  @$internal
  @override
  StoreController create() => StoreController();
}

String _$storeControllerHash() => r'0a645a1aaad1c7e20b48efb8288e30d13a997e8e';

abstract class _$StoreController
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
