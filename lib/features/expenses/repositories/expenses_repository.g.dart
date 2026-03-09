// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expenses_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(expensesRepository)
final expensesRepositoryProvider = ExpensesRepositoryProvider._();

final class ExpensesRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<ExpensesRepository>,
          ExpensesRepository,
          FutureOr<ExpensesRepository>
        >
    with
        $FutureModifier<ExpensesRepository>,
        $FutureProvider<ExpensesRepository> {
  ExpensesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'expensesRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$expensesRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<ExpensesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ExpensesRepository> create(Ref ref) {
    return expensesRepository(ref);
  }
}

String _$expensesRepositoryHash() =>
    r'12ac707a6a26eaceca3067533023692237830248';
