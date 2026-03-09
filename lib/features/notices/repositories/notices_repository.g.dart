// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notices_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(noticesRepository)
final noticesRepositoryProvider = NoticesRepositoryProvider._();

final class NoticesRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<NoticesRepository>,
          NoticesRepository,
          FutureOr<NoticesRepository>
        >
    with
        $FutureModifier<NoticesRepository>,
        $FutureProvider<NoticesRepository> {
  NoticesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'noticesRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$noticesRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<NoticesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<NoticesRepository> create(Ref ref) {
    return noticesRepository(ref);
  }
}

String _$noticesRepositoryHash() => r'489d4620e49f087602f62d469c9b51da914c027d';
