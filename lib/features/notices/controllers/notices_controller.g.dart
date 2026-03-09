// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notices_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(NoticesController)
final noticesControllerProvider = NoticesControllerProvider._();

final class NoticesControllerProvider
    extends
        $AsyncNotifierProvider<NoticesController, List<Map<String, dynamic>>> {
  NoticesControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'noticesControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$noticesControllerHash();

  @$internal
  @override
  NoticesController create() => NoticesController();
}

String _$noticesControllerHash() => r'7160fca85bd736a8814306b6f0263e6043a77e0d';

abstract class _$NoticesController
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
