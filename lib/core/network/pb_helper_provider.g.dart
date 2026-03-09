// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pb_helper_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(pbHelper)
final pbHelperProvider = PbHelperProvider._();

final class PbHelperProvider
    extends
        $FunctionalProvider<
          AsyncValue<PocketBase>,
          PocketBase,
          FutureOr<PocketBase>
        >
    with $FutureModifier<PocketBase>, $FutureProvider<PocketBase> {
  PbHelperProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pbHelperProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pbHelperHash();

  @$internal
  @override
  $FutureProviderElement<PocketBase> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<PocketBase> create(Ref ref) {
    return pbHelper(ref);
  }
}

String _$pbHelperHash() => r'ad8f97000e89133cf034fb43b9f3f030bd58b7ad';
