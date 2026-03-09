// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supplier_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(supplierRepository)
final supplierRepositoryProvider = SupplierRepositoryProvider._();

final class SupplierRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<SupplierRepository>,
          SupplierRepository,
          FutureOr<SupplierRepository>
        >
    with
        $FutureModifier<SupplierRepository>,
        $FutureProvider<SupplierRepository> {
  SupplierRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supplierRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supplierRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<SupplierRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SupplierRepository> create(Ref ref) {
    return supplierRepository(ref);
  }
}

String _$supplierRepositoryHash() =>
    r'55a0d36cc10214156d6712abe796b8b4a6124232';
