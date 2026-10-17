import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether the phone has a network connection. A connection can still fail (no
/// internet behind the Wi-Fi), so callers also treat failed requests as offline.
abstract class ConnectivityService {
  Future<bool> isOnline();
  Stream<bool> onlineChanges();
}

class DeviceConnectivity implements ConnectivityService {
  final _connectivity = Connectivity();

  static bool _online(List<ConnectivityResult> r) =>
      r.any((c) => c != ConnectivityResult.none);

  @override
  Future<bool> isOnline() async =>
      _online(await _connectivity.checkConnectivity());

  @override
  Stream<bool> onlineChanges() =>
      _connectivity.onConnectivityChanged.map(_online).distinct();
}
