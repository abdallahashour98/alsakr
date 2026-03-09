// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supplier_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SupplierController)
final supplierControllerProvider = SupplierControllerProvider._();

final class SupplierControllerProvider
    extends
        $AsyncNotifierProvider<SupplierController, List<Map<String, dynamic>>> {
  SupplierControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supplierControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supplierControllerHash();

  @$internal
  @override
  SupplierController create() => SupplierController();
}

String _$supplierControllerHash() =>
    r'873d260a9c60cf9854f079d24fa3983b8d54cfd9';

abstract class _$SupplierController
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
