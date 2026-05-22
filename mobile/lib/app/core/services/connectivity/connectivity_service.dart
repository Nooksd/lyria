import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final Uri _serverBaseUri;

  final _controller = StreamController<bool>.broadcast();
  Stream<bool> get onStatusChange => _controller.stream;

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  Timer? _pingTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  int _failedProbeRounds = 0;

  ConnectivityService({required String serverBaseUrl})
      : _serverBaseUri = Uri.parse(serverBaseUrl);

  Future<void> init() async {
    await _checkServerReachable();
    _schedulePing();

    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      if (results.contains(ConnectivityResult.none)) {
        _setOnline(false);
      } else {
        _checkServerReachable();
      }
    });
  }

  Future<void> _checkServerReachable() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      if (await _probeServer()) {
        _failedProbeRounds = 0;
        _setOnline(true);
        return;
      }

      if (attempt < 2) {
        await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }

    _failedProbeRounds++;
    if (_failedProbeRounds >= 3) {
      _setOnline(false);
    } else {
      debugPrint('[Connectivity] Probe failed ($_failedProbeRounds/3)');
    }
  }

  Future<bool> _probeServer() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final uri = _serverBaseUri.replace(path: '/health', query: null);
      final request =
          await client.getUrl(uri).timeout(const Duration(seconds: 4));
      final response =
          await request.close().timeout(const Duration(seconds: 4));
      await response.drain<void>();
      return response.statusCode < 500;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  void _setOnline(bool value) {
    if (_isOnline != value) {
      _isOnline = value;
      _controller.add(value);
      debugPrint('[Connectivity] Online: $value');
      _schedulePing();
    }
  }

  void _schedulePing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(
      _isOnline ? const Duration(seconds: 30) : const Duration(seconds: 10),
      (_) => _checkServerReachable(),
    );
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
