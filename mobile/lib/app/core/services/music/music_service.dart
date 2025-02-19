import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lyria/app/modules/music/domain/entities/lyrics.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';

class MusicService extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ConcatenatingAudioSource _playlist =
      ConcatenatingAudioSource(children: []);

  bool _isLoop = false;
  bool _isShuffle = false;
  bool get isLoop => _isLoop;
  bool get isShuffle => _isShuffle;
  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  final StreamController<void> _notificationDeletedController =
      StreamController<void>.broadcast();
  Stream<void> get notificationDeleted => _notificationDeletedController.stream;

  MusicService() {
    _init();
  }

  Future<void> _init() async {
    await _audioPlayer.setAudioSource(_playlist);
    _setupPlaybackListeners();
  }

  void _setupPlaybackListeners() {
    _audioPlayer.sequenceStateStream.listen((sequenceState) {
      if (sequenceState == null) return;

      final newQueue = sequenceState.sequence
          .map((source) => source.tag as MediaItem)
          .toList();
      updateQueue(newQueue);

      final currentItem = sequenceState.currentSource?.tag as MediaItem?;
      if (currentItem != null) {
        mediaItem.add(currentItem.copyWith(duration: _audioPlayer.duration));
      }
    });

    _audioPlayer.playbackEventStream.listen((event) {
      final playing = _audioPlayer.playing;
      final processingState = _audioPlayer.processingState;
      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            playing ? MediaControl.pause : MediaControl.play,
            MediaControl.skipToNext,
          ],
          systemActions: const {MediaAction.seek},
          androidCompactActionIndices: const [0, 1, 2],
          processingState: _convertProcessingState(processingState),
          playing: playing,
          updatePosition: _audioPlayer.position,
          bufferedPosition: _audioPlayer.bufferedPosition,
          speed: _audioPlayer.speed,
        ),
      );
    });

    _audioPlayer.durationStream.listen((duration) {
      final current = mediaItem.value;
      if (current != null && duration != null) {
        mediaItem.add(current.copyWith(duration: duration));
      }
    });
  }

  Future<void> setQueue(List<Music> queue, int currentIndex) async {
    await _playlist.clear();
    final sources = <AudioSource>[];
    for (final music in queue) {
      sources.add(await _createAudioSource(music));
    }

    await _playlist.addAll(sources);
    await _audioPlayer.setAudioSource(_playlist, initialIndex: currentIndex);

    if (_playlist.children.isEmpty) return;

    _audioPlayer.play();
  }

  Future<void> addToQueue(Music music) async {
    await _playlist.add(await _createAudioSource(music));
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _playlist.children.length) return;
    await _playlist.removeAt(index);
  }

  Future<void> toggleLoop() async {
    _isLoop = !_isLoop;
    await _audioPlayer.setLoopMode(_isLoop ? LoopMode.one : LoopMode.off);
  }

  Future<void> toggleShuffle() async {
    _isShuffle = !_isShuffle;
    await _audioPlayer.setShuffleModeEnabled(_isShuffle);
  }

  Future<void> clearQueue() async {
    await _playlist.clear();
    await stop();
  }

  @override
  Future<void> skipToNext() async {
    await _audioPlayer.seekToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    await _audioPlayer.seekToPrevious();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    try {
      if (index >= 0 && index < _playlist.children.length) {
        await _audioPlayer.seek(Duration.zero, index: index);

        if (!_audioPlayer.playing) {
          await _audioPlayer.play();
        }

        playbackState.add(playbackState.value.copyWith(
          updatePosition: Duration.zero,
          processingState:
              _convertProcessingState(_audioPlayer.processingState),
        ));
      }
    } catch (e) {
      debugPrint('Erro ao pular para índice $index: $e');
      throw Exception('Não foi possível pular para o índice solicitado');
    }
  }

  @override
  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  @override
  Future<void> play() async {
    await _audioPlayer.play();
  }

  @override
  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  @override
  Future<void> stop() async {
    await _audioPlayer.stop();
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
    ));
    await _playlist.clear();
  }

  Future<void> close() async {
    await stop();
    return super.stop();
  }

  @override
  Future<void> onNotificationDeleted() async {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      await stop();
    } else {
      _notificationDeletedController.add(null);
    }
    await super.onNotificationDeleted();
  }

  Future<AudioSource> _createAudioSource(Music music) async {
    try {
      final tempSource = AudioSource.uri(Uri.parse(music.url));
      final duration = tempSource.duration;

      return AudioSource.uri(
        Uri.parse(music.url),
        tag: convertMusicToMediaItem(music, duration),
      );
    } catch (e) {
      debugPrint('Erro ao carregar música ${music.id}: $e');
      return AudioSource.uri(
        Uri.parse(music.url),
        tag: convertMusicToMediaItem(music, null),
      );
    }
  }

  MediaItem convertMusicToMediaItem(Music music, Duration? duration) {
    return MediaItem(
      id: music.id,
      album: music.albumName,
      title: music.name,
      artist: music.artistName,
      artUri: Uri.parse(music.coverUrl),
      duration: duration,
      extras: {
        'url': music.url,
        'color': music.color,
        'waveform': music.waveform,
        'lyrics': music.lyrics?.map((lyric) => lyric.toJson()).toList(),
        'artistId': music.artistId,
        'albumId': music.albumId,
        'genre': music.genre,
      },
      displayTitle: music.name,
      displaySubtitle: music.artistName,
      displayDescription: music.albumName,
    );
  }

  Music musicFromMediaItem(MediaItem item) {
    return Music(
      id: item.id,
      url: item.extras?['url'] ?? '',
      name: item.title,
      artistId: item.extras?['artistId'] ?? '',
      artistName: item.artist ?? '',
      albumId: item.extras?['albumId'] ?? '',
      albumName: item.album ?? '',
      waveform: item.extras?['waveform'] != null
          ? List<double>.from(item.extras!['waveform'])
          : [],
      genre: item.extras?['genre'] ?? '',
      color: item.extras?['color'] ?? '#FFFFFF',
      coverUrl: item.artUri.toString(),
      lyrics: item.extras?['lyrics'] != null
          ? (item.extras!['lyrics'] as List)
              .map((e) => LyricLine.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  AudioProcessingState _convertProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
      default:
        return AudioProcessingState.idle;
    }
  }
}
