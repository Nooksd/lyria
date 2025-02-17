import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lyria/app/core/services/music/music_service.dart';
import 'package:lyria/app/core/themes/theme_cubit.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_states.dart';

class MusicCubit extends Cubit<MusicState> {
  final ThemeCubit themeCubit;
  final MusicService _musicService;

  MusicCubit(this.themeCubit, this._musicService) : super(MusicInitial()) {
    _setupAudioListeners();
  }

  List<Music> get queue => _musicService.actualQueue;
  int get currentIndex => _musicService.currentIndex;
  bool get isLoop => _musicService.isLoop;
  bool get isShuffle => _musicService.isShuffle;

  Stream<Duration> get positionStream => _musicService.rawPositionStream;
  Stream<Duration?> get durationStream =>
      _musicService.mediaItem.map((item) => item?.duration);
  Duration? get duration => _musicService.mediaItem.value?.duration;
  Duration get position => _musicService.playbackState.value.position;

  void _setupAudioListeners() {
    _musicService.playbackState.listen((state) {
      _updatePlaybackState(state);
    });

    _musicService.mediaItem.listen((mediaItem) {
      if (mediaItem != null) {
        _updateCurrentMusic(mediaItem);
        _updatePlaybackState(_musicService.playbackState.value);
      }
    });
  }

  Future<void> setQueue(List<Music> queue, int currentIndex) async =>
      _musicService.setQueue(queue, currentIndex);

  Future<void> addToQueue(Music music) async {
    await _musicService.addToQueue(music);
    if (_musicService.actualQueue.length == 1) {
      await _musicService.play();
    }
  }

  void playPause() {
    if (_musicService.playbackState.value.playing) {
      _musicService.pause();
    } else {
      _musicService.play();
    }
  }

  Future<void> next() async => _musicService.skipToNext();

  Future<void> previous() async => _musicService.skipToPrevious();

  void toggleLoop() => _musicService.toggleLoop();

  void toggleShuffle() => _musicService.toggleShuffle();

  Future<void> seekTo(Duration position) async => _musicService.seek(position);

  Future<void> removeFromQueue(Music music) async =>
      _musicService.removeFromQueue(music);

  Future<void> clearQueue() async => _musicService.clearQueue();

  Future<void> skipToIndex(int index) async =>
      _musicService.skipToQueueItem(index);

  Future<void> stop() async {
    await _musicService.stop();
    themeCubit.updatePrimaryColor(Colors.white);
    emit(MusicStopped());
  }

    void _updatePlaybackState(PlaybackState state) {
    if (_musicService.actualQueue.isEmpty) return;

    emit(MusicPlaying(
      currentMusic: _musicService.actualQueue[_musicService.currentIndex],
      queue: _musicService.actualQueue,
      isPlaying: state.playing,
      currentIndex: _musicService.currentIndex,
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
