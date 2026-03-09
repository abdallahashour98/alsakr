// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sales_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Sales controller — reads/writes exclusively from local SQLite.
/// Covers Sales, Returns, Receipts, and Delivery Orders.

@ProviderFor(SalesController)
final salesControllerProvider = SalesControllerProvider._();

/// Sales controller — reads/writes exclusively from local SQLite.
/// Covers Sales, Returns, Receipts, and Delivery Orders.
final class SalesControllerProvider
    extends
        $AsyncNotifierProvider<SalesController, List<Map<String, dynamic>>> {
  /// Sales controller — reads/writes exclusively from local SQLite.
  /// Covers Sales, Returns, Receipts, and Delivery Orders.
  SalesControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'salesControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$salesControllerHash();

  @$internal
  @override
  SalesController create() => SalesController();
}

String _$salesControllerHash() => r'224f17bd81abf3b8d25cdd4a694fe4526940d513';

/// Sales controller — reads/writes exclusively from local SQLite.
/// Covers Sales, Returns, Receipts, and Delivery Orders.

abstract class _$SalesController
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
