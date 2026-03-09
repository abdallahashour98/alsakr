// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connectivity_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// A Riverpod provider that emits `true` when the device has confirmed
/// network connectivity to the PocketBase server, and `false` otherwise.
///
/// It goes beyond simple WiFi/mobile detection by performing a health
/// check against PocketBase to confirm real server reachability.

@ProviderFor(ConnectivityStatus)
final connectivityStatusProvider = ConnectivityStatusProvider._();

/// A Riverpod provider that emits `true` when the device has confirmed
/// network connectivity to the PocketBase server, and `false` otherwise.
///
/// It goes beyond simple WiFi/mobile detection by performing a health
/// check against PocketBase to confirm real server reachability.
final class ConnectivityStatusProvider
    extends $StreamNotifierProvider<ConnectivityStatus, bool> {
  /// A Riverpod provider that emits `true` when the device has confirmed
  /// network connectivity to the PocketBase server, and `false` otherwise.
  ///
  /// It goes beyond simple WiFi/mobile detection by performing a health
  /// check against PocketBase to confirm real server reachability.
  ConnectivityStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectivityStatusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectivityStatusHash();

  @$internal
  @override
  ConnectivityStatus create() => ConnectivityStatus();
}

String _$connectivityStatusHash() =>
    r'd9100263bdf9cf3a2c832552c56068ecf95365be';

/// A Riverpod provider that emits `true` when the device has confirmed
/// network connectivity to the PocketBase server, and `false` otherwise.
///
/// It goes beyond simple WiFi/mobile detection by performing a health
/// check against PocketBase to confirm real server reachability.

abstract class _$ConnectivityStatus extends $StreamNotifier<bool> {
  Stream<bool> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
