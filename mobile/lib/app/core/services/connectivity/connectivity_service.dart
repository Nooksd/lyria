import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final String _serverHost;
  final int _serverPort;

  final _controller = StreamController<bool>.broadcast();
  Stream<bool> get onStatusChange => _controller.stream;

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  Timer? _pingTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  ConnectivityService({required String serverBaseUrl})
      : _serverHost = Uri.parse(serverBaseUrl).host,
        _serverPort = Uri.parse(serverBaseUrl).port;

  Future<void> init() async {
    await _checkServerReachable();

    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      if (results.contains(ConnectivityResult.none)) {
        _setOnline(false);
      } else {
        _checkServerReachable();
      }
    });

    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkServerReachable();
    });
  }

  Future<void> _checkServerReachable() async {
    try {
      final socket = await Socket.connect(
        _serverHost,
        _serverPort,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      _setOnline(true);
    } catch (_) {
      _setOnline(false);
    }
  }

  void _setOnline(bool value) {
    if (_isOnline != value) {
      _isOnline = value;
      _controller.add(value);
      debugPrint('[Connectivity] Online: $value');
    }
  }

  Future<void> checkNow() async {
    await _checkServerReachable();
  }

  void dispose() {
    _pingTimer?.cancel();
    _connectivitySub?.cancel();
    _controller.close();
  }
}
