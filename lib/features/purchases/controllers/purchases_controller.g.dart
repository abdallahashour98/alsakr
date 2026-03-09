// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchases_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Purchases controller — reads/writes exclusively from local SQLite.
/// Covers Purchases, Purchase Returns, and Supplier Payments.

@ProviderFor(PurchasesController)
final purchasesControllerProvider = PurchasesControllerProvider._();

/// Purchases controller — reads/writes exclusively from local SQLite.
/// Covers Purchases, Purchase Returns, and Supplier Payments.
final class PurchasesControllerProvider
    extends
        $AsyncNotifierProvider<
          PurchasesController,
          List<Map<String, dynamic>>
        > {
  /// Purchases controller — reads/writes exclusively from local SQLite.
  /// Covers Purchases, Purchase Returns, and Supplier Payments.
  PurchasesControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'purchasesControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$purchasesControllerHash();

  @$internal
  @override
  PurchasesController create() => PurchasesController();
}

String _$purchasesControllerHash() =>
    r'81ed5d3cafe0ea44c6438f1268af82810e0c5cb1';

/// Purchases controller — reads/writes exclusively from local SQLite.
/// Covers Purchases, Purchase Returns, and Supplier Payments.

abstract class _$PurchasesController
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
