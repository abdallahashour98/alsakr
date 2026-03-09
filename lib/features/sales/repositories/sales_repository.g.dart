// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sales_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(salesRepository)
final salesRepositoryProvider = SalesRepositoryProvider._();

final class SalesRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<SalesRepository>,
          SalesRepository,
          FutureOr<SalesRepository>
        >
    with $FutureModifier<SalesRepository>, $FutureProvider<SalesRepository> {
  SalesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'salesRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$salesRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<SalesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SalesRepository> create(Ref ref) {
    return salesRepository(ref);
  }
}

String _$salesRepositoryHash() => r'99779300021fa76041d11d570215841e1bb6a99e';
