// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expenses_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ExpensesController)
final expensesControllerProvider = ExpensesControllerProvider._();

final class ExpensesControllerProvider
    extends
        $AsyncNotifierProvider<ExpensesController, List<Map<String, dynamic>>> {
  ExpensesControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'expensesControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$expensesControllerHash();

  @$internal
  @override
  ExpensesController create() => ExpensesController();
}

String _$expensesControllerHash() =>
    r'd05792d5e4a1133ac8d8f3469919c75b612204bb';

abstract class _$ExpensesController
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
