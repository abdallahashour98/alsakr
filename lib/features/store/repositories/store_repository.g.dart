// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'store_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(storeRepository)
final storeRepositoryProvider = StoreRepositoryProvider._();

final class StoreRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<StoreRepository>,
          StoreRepository,
          FutureOr<StoreRepository>
        >
    with $FutureModifier<StoreRepository>, $FutureProvider<StoreRepository> {
  StoreRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storeRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storeRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<StoreRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<StoreRepository> create(Ref ref) {
    return storeRepository(ref);
  }
}

String _$storeRepositoryHash() => r'17d5593fd4f801a4da4929e2d5a9bf83a73ce496';
