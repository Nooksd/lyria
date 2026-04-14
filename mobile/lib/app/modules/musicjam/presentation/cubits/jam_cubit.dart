import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lyria/app/core/services/http/my_http_client.dart';
import 'package:lyria/app/core/services/storege/my_local_storage.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_cubit.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_states.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class JamState {
  final bool isInJam;
  final String? simpleId;
  final List<Map<String, dynamic>> participants;
  final bool isConnecting;

  const JamState({
    this.isInJam = false,
    this.simpleId,
    this.participants = const [],
    this.isConnecting = false,
  });

  JamState copyWith({
    bool? isInJam,
    String? simpleId,
    List<Map<String, dynamic>>? participants,
    bool? isConnecting,
  }) {
    return JamState(
      isInJam: isInJam ?? this.isInJam,
      simpleId: simpleId ?? this.simpleId,
      participants: participants ?? this.participants,
      isConnecting: isConnecting ?? this.isConnecting,
    );
  }
}

class JamCubit extends Cubit<JamState> {
  final MusicCubit _musicCubit;
  final MyHttpClient _http;
  final MyLocalStorage _storage;

  WebSocketChannel? _channel;
  StreamSubscription? _playbackSub;
  StreamSubscription? _musicStateSub;
  Timer? _positionSyncTimer;
  bool _suppressBroadcast = false;
  bool? _lastKnownPlaying;
  List<String>? _lastKnownQueueIds;
  int? _lastKnownIndex;

  JamCubit({
    required MusicCubit musicCubit,
    required MyHttpClient http,
    required MyLocalStorage storage,
  })  : _musicCubit = musicCubit,
        _http = http,
        _storage = storage,
        super(const JamState());

  Future<String?> createJam() async {
    try {
      emit(state.copyWith(isConnecting: true));
      final response = await _http.post('/musicjam/create');
      final data = response['data'];
      final simpleId = data['details']['simpleId'] as String;
      emit(state.copyWith(
        isInJam: true,
        simpleId: simpleId,
        isConnecting: false,
      ));
      await _connectWebSocket(simpleId);
      return simpleId;
    } catch (e) {
      emit(state.copyWith(isConnecting: false));
      debugPrint('Error creating jam: $e');
      return null;
    }
  }

  Future<bool> joinJam(String code) async {
    try {
      emit(state.copyWith(isConnecting: true));
      final response = await _http.get('/musicjam/join/$code');
      if (response['status'] != 200) {
        emit(state.copyWith(isConnecting: false));
        return false;
      }
      emit(state.copyWith(
        isInJam: true,
        simpleId: code,
        isConnecting: false,
      ));
      await _connectWebSocket(code);
      return true;
    } catch (e) {
      emit(state.copyWith(isConnecting: false));
      debugPrint('Error joining jam: $e');
      return false;
    }
  }

  Future<void> _connectWebSocket(String simpleId) async {
    final token = await _storage.get('accessToken');
    final uri = Uri.parse(
        'ws://192.168.1.101:9000/musicjam/ws/$simpleId?token=$token');

    try {
      _channel = WebSocketChannel.connect(uri);
      _channel!.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data);
            _handleMessage(msg);
          } catch (e) {
            debugPrint('Error parsing WS message: $e');
          }
        },
        onDone: () {
          debugPrint('WS connection closed');
        },
        onError: (e) {
          debugPrint('WS error: $e');
        },
      );
      _setupOutgoingBroadcast();
    } catch (e) {
      debugPrint('Error connecting WS: $e');
    }
  }

  void _setupOutgoingBroadcast() {
    _playbackSub?.cancel();
    _musicStateSub?.cancel();
    _positionSyncTimer?.cancel();

    _positionSyncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!state.isInJam || _suppressBroadcast) return;
      final musicState = _musicCubit.state;
      if (musicState is MusicPlaying && musicState.isPlaying) {
        final pos = _musicCubit.currentPosition.inMilliseconds / 1000.0;
        _sendMessage('position_sync', {'position': pos});
      }
    });

    _musicStateSub = _musicCubit.stream.listen((musicState) {
      if (_suppressBroadcast || !state.isInJam) return;

      if (musicState is MusicPlaying) {
        final queueIds = musicState.queue.map((m) => m.id).toList();
        final queueChanged = _lastKnownQueueIds == null ||
            !listEquals(queueIds, _lastKnownQueueIds);

        if (queueChanged) {
          _lastKnownQueueIds = queueIds;
          _lastKnownIndex = musicState.currentIndex;
          _lastKnownPlaying = musicState.isPlaying;
          _sendMessage('set_queue', {
            'queue': musicState.queue.map((m) => m.toJson()).toList(),
            'currentIndex': musicState.currentIndex,
            'position': 0,
            'playing': musicState.isPlaying,
          });
          return;
        }

        final indexChanged = _lastKnownIndex != null &&
            _lastKnownIndex != musicState.currentIndex;
        if (indexChanged) {
          _lastKnownIndex = musicState.currentIndex;
          _sendMessage('skip_to', {
            'index': musicState.currentIndex,
          });
          return;
        }
        _lastKnownIndex = musicState.currentIndex;
      }
    });

    _playbackSub = _musicCubit.playbackStateStream.listen((playbackState) {
      if (_suppressBroadcast || !state.isInJam) return;
      if (_lastKnownPlaying == playbackState.playing) return;
      _lastKnownPlaying = playbackState.playing;

      final pos = playbackState.updatePosition.inMilliseconds / 1000.0;
      if (playbackState.playing) {
        final musicState = _musicCubit.state;
        final musicId =
            musicState is MusicPlaying ? musicState.currentMusic.id : '';
        _sendMessage('play', {'musicId': musicId, 'position': pos});
      } else {
        _sendMessage('pause', {'position': pos});
      }
    });
  }

  void _handleMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    final payload = msg['payload'] as Map<String, dynamic>? ?? {};

    _suppressBroadcast = true;

    switch (type) {
      case 'sync':
        final participants = (payload['participants'] as List? ?? [])
            .map((p) => Map<String, dynamic>.from(p))
            .toList();
        emit(state.copyWith(participants: participants));

        final playing = payload['playing'] as bool? ?? false;
        final pos = (payload['position'] as num?)?.toDouble() ?? 0;
        _lastKnownPlaying = playing;
        if (pos > 0) {
          _musicCubit.seekTo(
              Duration(milliseconds: (pos * 1000).toInt()));
        }
        if (playing) {
          _musicCubit.play();
        }
        break;

      case 'set_queue':
        final queueData = (payload['queue'] as List? ?? [])
            .map((m) => Music.fromJson(Map<String, dynamic>.from(m)))
            .toList();
        final currentIndex = payload['currentIndex'] as int? ?? 0;
        final position =
            (payload['position'] as num?)?.toDouble() ?? 0;
        final playing = payload['playing'] as bool? ?? true;

        if (queueData.isNotEmpty) {
          final queueIds = queueData.map((m) => m.id).toList();
          if (listEquals(queueIds, _lastKnownQueueIds)) {
            _unsuppress();
            break;
          }
          _lastKnownQueueIds = queueIds;
          _lastKnownIndex = currentIndex;
          _lastKnownPlaying = playing;
          _musicCubit
              .setQueue(queueData, currentIndex, null)
              .then((_) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (position > 0) {
                _musicCubit.seekTo(Duration(
                    milliseconds: (position * 1000).toInt()));
              }
              if (!playing) {
                _musicCubit.pause();
              }
            });
          });
        }
        break;

      case 'play':
        final pos = (payload['position'] as num?)?.toDouble() ?? 0;
        _lastKnownPlaying = true;
        _musicCubit
            .seekTo(Duration(milliseconds: (pos * 1000).toInt()));
        _musicCubit.play();
        break;

      case 'pause':
        final pos = (payload['position'] as num?)?.toDouble() ?? 0;
        _lastKnownPlaying = false;
        _musicCubit
            .seekTo(Duration(milliseconds: (pos * 1000).toInt()));
        _musicCubit.pause();
        break;

      case 'seek':
        final pos = (payload['position'] as num?)?.toDouble() ?? 0;
        _musicCubit
            .seekTo(Duration(milliseconds: (pos * 1000).toInt()));
        break;

      case 'skip_to':
        final index = payload['index'] as int? ?? 0;
        _lastKnownIndex = index;
        _musicCubit.skipToIndex(index);
        break;

      case 'skip_next':
        _musicCubit.next();
        break;

      case 'user_joined':
        final participants = (payload['participants'] as List? ?? [])
            .map((p) => Map<String, dynamic>.from(p))
            .toList();
        emit(state.copyWith(participants: participants));
        _broadcastCurrentState();
        break;

      case 'sync_state':
        final queueData = (payload['queue'] as List? ?? [])
            .map((m) => Music.fromJson(Map<String, dynamic>.from(m)))
            .toList();
        final currentIndex = payload['currentIndex'] as int? ?? 0;
        final position =
            (payload['position'] as num?)?.toDouble() ?? 0;
        final playing = payload['playing'] as bool? ?? true;

        if (queueData.isNotEmpty) {
          final queueIds = queueData.map((m) => m.id).toList();
          if (listEquals(queueIds, _lastKnownQueueIds)) {
            if (position > 0) {
              _musicCubit.seekTo(Duration(
                  milliseconds: (position * 1000).toInt()));
            }
            _unsuppress();
            break;
          }
          _lastKnownQueueIds = queueIds;
          _lastKnownIndex = currentIndex;
          _lastKnownPlaying = playing;
          _musicCubit
              .setQueue(queueData, currentIndex, null)
              .then((_) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (position > 0) {
                _musicCubit.seekTo(Duration(
                    milliseconds: (position * 1000).toInt()));
              }
              if (!playing) {
                _musicCubit.pause();
              }
            });
          });
        }
        break;

      case 'position_sync':
        final pos = (payload['position'] as num?)?.toDouble() ?? 0;
        final currentPos =
            _musicCubit.currentPosition.inMilliseconds / 1000.0;
        if ((pos - currentPos).abs() > 2.0) {
          _musicCubit
              .seekTo(Duration(milliseconds: (pos * 1000).toInt()));
        }
        break;

      case 'user_left':
        final participants = (payload['participants'] as List? ?? [])
            .map((p) => Map<String, dynamic>.from(p))
            .toList();
        emit(state.copyWith(participants: participants));
        break;
    }

    _unsuppress();
  }

  void _broadcastCurrentState() {
    final musicState = _musicCubit.state;
    if (musicState is MusicPlaying && musicState.queue.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () {
        final curState = _musicCubit.state;
        if (curState is MusicPlaying) {
          final pos =
              _musicCubit.currentPosition.inMilliseconds / 1000.0;
          _sendMessage('sync_state', {
            'queue': curState.queue.map((m) => m.toJson()).toList(),
            'currentIndex': curState.currentIndex,
            'position': pos,
            'playing': curState.isPlaying,
          });
        }
      });
    }
  }

  void _unsuppress() {
    Future.delayed(const Duration(milliseconds: 800), () {
      _suppressBroadcast = false;
    });
  }

  void _sendMessage(String type, Map<String, dynamic> payload) {
    if (_channel == null) return;
    try {
      _channel!.sink.add(jsonEncode({
        'type': type,
        'payload': payload,
      }));
    } catch (e) {
      debugPrint('Error sending WS message: $e');
    }
  }

  Future<void> leaveJam() async {
    final simpleId = state.simpleId;

    _playbackSub?.cancel();
    _musicStateSub?.cancel();
    _positionSyncTimer?.cancel();
    _playbackSub = null;
    _musicStateSub = null;
    _positionSyncTimer = null;

    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;

    _lastKnownPlaying = null;
    _lastKnownQueueIds = null;
    _lastKnownIndex = null;
    _suppressBroadcast = false;

    emit(const JamState());

    if (simpleId != null) {
      try {
        await _http.get('/musicjam/leave/$simpleId');
      } catch (_) {}
    }
  }

  @override
  Future<void> close() {
    _playbackSub?.cancel();
    _musicStateSub?.cancel();
    _positionSyncTimer?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    return super.close();
  }
}
