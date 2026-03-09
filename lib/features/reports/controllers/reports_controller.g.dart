// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reports_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ReportsData)
final reportsDataProvider = ReportsDataFamily._();

final class ReportsDataProvider
    extends $AsyncNotifierProvider<ReportsData, Map<String, double>> {
  ReportsDataProvider._({
    required ReportsDataFamily super.from,
    required ({String? startDate, String? endDate}) super.argument,
  }) : super(
         retry: null,
         name: r'reportsDataProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reportsDataHash();

  @override
  String toString() {
    return r'reportsDataProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  ReportsData create() => ReportsData();

  @override
  bool operator ==(Object other) {
    return other is ReportsDataProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reportsDataHash() => r'90cd2591282b1fe6e83dd11968eb8d03879696b4';

final class ReportsDataFamily extends $Family
    with
        $ClassFamilyOverride<
          ReportsData,
          AsyncValue<Map<String, double>>,
          Map<String, double>,
          FutureOr<Map<String, double>>,
          ({String? startDate, String? endDate})
        > {
  ReportsDataFamily._()
    : super(
        retry: null,
        name: r'reportsDataProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ReportsDataProvider call({String? startDate, String? endDate}) =>
      ReportsDataProvider._(
        argument: (startDate: startDate, endDate: endDate),
        from: this,
      );

  @override
  String toString() => r'reportsDataProvider';
}

abstract class _$ReportsData extends $AsyncNotifier<Map<String, double>> {
  late final _$args = ref.$arg as ({String? startDate, String? endDate});
  String? get startDate => _$args.startDate;
  String? get endDate => _$args.endDate;

  FutureOr<Map<String, double>> build({String? startDate, String? endDate});
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<Map<String, double>>, Map<String, double>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Map<String, double>>, Map<String, double>>,
              AsyncValue<Map<String, double>>,
              Object?,
              Object?
            >;
    element.handleCreate(
      ref,
      () => build(startDate: _$args.startDate, endDate: _$args.endDate),
    );
  }
}
