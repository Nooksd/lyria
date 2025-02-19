import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lyria/app/core/themes/theme_cubit.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_states.dart';
import 'package:lyria/app/core/services/music/music_service.dart';

class MusicCubit extends Cubit<MusicState> {
  final ThemeCubit themeCubit;
  final AudioHandler _audioHandler;

  MusicCubit(this.themeCubit, this._audioHandler) : super(MusicInitial()) {
    _setupAudioListeners();
  }

  MusicService get _musicService => _audioHandler as MusicService;
  int get currentIndex =>
      state is MusicPlaying ? (state as MusicPlaying).currentIndex : 0;
  Stream<Duration> get positionStream =>
      (_audioHandler as MusicService).positionStream;
  Stream<Duration> get durationStream => _audioHandler.mediaItem
      .map((item) => item?.duration ?? Duration.zero)
      .distinct();
  Duration get duration =>
      _audioHandler.mediaItem.value?.duration ?? Duration.zero;
  Stream<PlaybackState> get playbackStateStream => _audioHandler.playbackState;
  List<MediaItem> get queue => _audioHandler.queue.value;

  void _setupAudioListeners() {
    (_audioHandler as MusicService).notificationDeleted.listen((_) async {
      await stop();
    });

    _audioHandler.playbackState.listen((state) {
      _updatePlaybackState(state);
    });
    _audioHandler.mediaItem.listen((mediaItem) {
      if (mediaItem != null) {
        _updateCurrentMusic(mediaItem);
        _updatePlaybackState(_audioHandler.playbackState.value);
      }
    });
  }

  Future<void> setQueue(List<Music> queue, int currentIndex) async {
    await _musicService.setQueue(queue, currentIndex);
  }

  Future<void> addToQueue(Music music) async {
    await _musicService.addToQueue(music);
    if (_audioHandler.queue.value.length == 1) {
      await _audioHandler.play();
    }
  }

  Future<void> removeFromQueue(int index) async {
    await _musicService.removeFromQueue(index);
  }

  Future<void> clearQueue() async {
    await _musicService.clearQueue();
  }

  Future<void> playPause() async {
    if (_audioHandler.playbackState.value.playing) {
      await _audioHandler.pause();
    } else {
      await _audioHandler.play();
    }
  }

  Future<void> toggleLoop() async {
    await _musicService.toggleLoop();
  }

  Future<void> toggleShuffle() async {
    await _musicService.toggleShuffle();
  }

  Future<void> next() async => await _audioHandler.skipToNext();

  Future<void> previous() async => await _audioHandler.skipToPrevious();

  Future<void> skipToIndex(int index) async {
    await _audioHandler.skipToQueueItem(index);
  }

  Future<void> seekTo(Duration position) async =>
      await _audioHandler.seek(position);

  Future<void> stop() async {
    try {
      await _audioHandler.stop();
      themeCubit.updatePrimaryColor(Colors.white);
      emit(MusicStopped());
    } catch (e) {
      debugPrint('Erro ao parar música: $e');
    }
  }

  void _updatePlaybackState(PlaybackState state) {
    if (state.processingState == AudioProcessingState.idle &&
        _audioHandler.mediaItem.value == null) {
      emit(MusicStopped());
      return;
    }

    final mediaQueue = _audioHandler.queue.value;
    if (mediaQueue.isEmpty) {
      emit(MusicStopped());
      return;
    }
    final List<Music> musicQueue = mediaQueue
        .map((item) => _musicService.musicFromMediaItem(item))
        .toList();

    final currentMediaItem = _audioHandler.mediaItem.value;
    if (currentMediaItem == null) return;
    final Music currentMusic =
        _musicService.musicFromMediaItem(currentMediaItem);
    final currentIdx =
        musicQueue.indexWhere((item) => item.id == currentMediaItem.id);

    emit(MusicPlaying(
      currentMusic: currentMusic,
      queue: musicQueue,
      isPlaying: state.playing,
      currentIndex: currentIdx < 0 ? 0 : currentIdx,
      isLoop: _musicService.isLoop,
      isShuffle: _musicService.isShuffle,
    ));
  }

  void _updateCurrentMusic(MediaItem mediaItem) {
    final newColor = Color(
      int.parse(mediaItem.extras!['color'].replaceFirst('#', '0xFF')),
    );
    themeCubit.updatePrimaryColor(newColor);
  }
}
