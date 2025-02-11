import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_states.dart';

class MusicCubit extends Cubit<MusicState> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<Music> _queue = [];
  int _currentIndex = 0;
  bool _isLoop = false;
  bool _isShuffle = false;

  MusicCubit() : super(MusicInitial());

  Future<void> setQueue(List<Music> queue) async {
    _queue = queue;
    _currentIndex = 0;
    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    if (_queue.isEmpty) return;

    final currentMusic = _queue[_currentIndex];

    try {
      emit(MusicLoading());
      await _audioPlayer.setUrl(currentMusic.audioUrl);
      _audioPlayer.play();
      emit(MusicPlaying(
        currentMusic: currentMusic,
        queue: _queue,
        currentIndex: _currentIndex,
        isLoop: _isLoop,
        isShuffle: _isShuffle,
      ));
    } catch (e) {
      emit(MusicError("Erro ao carregar a música."));
    }
  }

  void playPause() {
    if (_audioPlayer.playing) {
      _audioPlayer.pause();
      emit(MusicPaused());
    } else {
      _audioPlayer.play();
      emit(MusicPlaying(
        currentMusic: _queue[_currentIndex],
        queue: _queue,
        currentIndex: _currentIndex,
        isLoop: _isLoop,
        isShuffle: _isShuffle,
      ));
    }
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;

    if (_isLoop) {
      await _playCurrent();
    } else if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      await _playCurrent();
    } else {
      emit(MusicStopped());
    }
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;

    if (_currentIndex > 0) {
      _currentIndex--;
      await _playCurrent();
    } else {
      await _playCurrent();
    }
  }

  void toggleLoop() {
    _isLoop = !_isLoop;
    emit(MusicPlaying(
      currentMusic: _queue[_currentIndex],
      queue: _queue,
      currentIndex: _currentIndex,
      isLoop: _isLoop,
      isShuffle: _isShuffle,
    ));
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;

    if (_isShuffle) {
      List<Music> tempQueue = _queue.sublist(_currentIndex + 1);
      tempQueue.shuffle(Random());
      _queue = _queue.sublist(0, _currentIndex + 1) + tempQueue;
    }

    emit(MusicPlaying(
      currentMusic: _queue[_currentIndex],
      queue: _queue,
      currentIndex: _currentIndex,
      isLoop: _isLoop,
      isShuffle: _isShuffle,
    ));
  }

  @override
  Future<void> close() {
    _audioPlayer.dispose();
    return super.close();
  }
}
