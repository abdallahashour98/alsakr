// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchases_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(purchasesRepository)
final purchasesRepositoryProvider = PurchasesRepositoryProvider._();

final class PurchasesRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<PurchasesRepository>,
          PurchasesRepository,
          FutureOr<PurchasesRepository>
        >
    with
        $FutureModifier<PurchasesRepository>,
        $FutureProvider<PurchasesRepository> {
  PurchasesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'purchasesRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$purchasesRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<PurchasesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PurchasesRepository> create(Ref ref) {
    return purchasesRepository(ref);
  }
}

String _$purchasesRepositoryHash() =>
    r'44633443720ffb7348122f08f3cb2a1b32f84c42';
