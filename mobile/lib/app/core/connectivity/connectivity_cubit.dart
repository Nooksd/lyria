import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lyria/app/core/services/connectivity/connectivity_service.dart';

class ConnectivityCubit extends Cubit<bool> {
  final ConnectivityService _connectivityService;
  StreamSubscription<bool>? _sub;

  /// State: true = online, false = offline
  ConnectivityCubit({required ConnectivityService connectivityService})
      : _connectivityService = connectivityService,
        super(connectivityService.isOnline) {
    _sub = _connectivityService.onStatusChange.listen((isOnline) {
      emit(isOnline);
    });
  }

  bool get isOnline => state;

  Future<void> checkNow() async {
    await _connectivityService.checkNow();
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
