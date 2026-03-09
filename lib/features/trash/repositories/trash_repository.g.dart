// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trash_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(trashRepository)
final trashRepositoryProvider = TrashRepositoryProvider._();

final class TrashRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<TrashRepository>,
          TrashRepository,
          FutureOr<TrashRepository>
        >
    with $FutureModifier<TrashRepository>, $FutureProvider<TrashRepository> {
  TrashRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trashRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trashRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<TrashRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TrashRepository> create(Ref ref) {
    return trashRepository(ref);
  }
}

String _$trashRepositoryHash() => r'70e5cedc57698a9d124d4544a01e15b155e3f20f';
