import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:al_sakr/core/network/pb_helper_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_service.g.dart';

/// A Riverpod provider that emits `true` when the device has confirmed
/// network connectivity to the PocketBase server, and `false` otherwise.
///
/// It goes beyond simple WiFi/mobile detection by performing a health
/// check against PocketBase to confirm real server reachability.
@Riverpod(keepAlive: true)
class ConnectivityStatus extends _$ConnectivityStatus {
  StreamSubscription? _subscription;

  @override
  Stream<bool> build() async* {
    // Emit an initial value based on current connectivity.
    bool lastStatus = await _checkRealConnectivity();
    yield lastStatus;

    // Listen for connectivity changes.
    final controller = StreamController<bool>();

    _subscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) async {
      // connectivity_plus v7 returns List<ConnectivityResult>
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      if (!hasNetwork) {
        if (lastStatus != false) {
          lastStatus = false;
          controller.add(false);
        }
      } else {
        // Confirm real connectivity by hitting PocketBase health endpoint.
        final isReachable = await _checkRealConnectivity();
        if (lastStatus != isReachable) {
          lastStatus = isReachable;
          controller.add(isReachable);
        }
      }
    });

    // Fallback polling for unreliable connectivity_plus events (e.g. on Linux/Desktop)
    final timer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final isReachable = await _checkRealConnectivity();
      if (lastStatus != isReachable) {
        lastStatus = isReachable;
        controller.add(isReachable);
      }
    });

    ref.onDispose(() {
      _subscription?.cancel();
      timer.cancel();
      controller.close();
    });

    yield* controller.stream;
  }

  /// Attempts a health-check request to PocketBase.
  /// Returns `true` if the server responds, `false` otherwise.
  Future<bool> _checkRealConnectivity() async {
    try {
      final health = await globalPb.health.check().timeout(
        const Duration(seconds: 5),
      );
      return health.code == 200;
    } catch (_) {
      return false;
    }
  }
}
