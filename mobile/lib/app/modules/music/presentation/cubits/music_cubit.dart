import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lyria/app/core/themes/theme_cubit.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_states.dart';

class MusicCubit extends Cubit<MusicState> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ThemeCubit themeCubit;
  List<Music> _queue = [];
  int _currentIndex = 0;
  bool _isLoop = false;
  bool _isShuffle = false;

  MusicCubit(this.themeCubit) : super(MusicInitial());

  List<Music> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isLoop => _isLoop;
  bool get isShuffle => _isShuffle;

  Future<void> setQueue(List<Music> queue, int currentIndex) async {
    _queue = queue;
    _currentIndex = currentIndex;
    await _playCurrent();
  }

  Future<void> addToQueue(Music music) async {
    _queue.add(music);
    await _playCurrent();
  }

  Future<void> removeFromQueue(Music music) async {
    _queue.remove(music);
    await _playCurrent();
  }

  Future<void> clearQueue() async {
    _queue.clear();
    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    if (_queue.isEmpty) return;

    final currentMusic = _queue[_currentIndex];

    try {
      emit(MusicLoading());
      await _audioPlayer.setUrl(currentMusic.url);
      _audioPlayer.play();

      final newColor =
          Color(int.parse(currentMusic.color.replaceFirst('#', '0xFF')));
      themeCubit.updatePrimaryColor(newColor);

      emit(MusicPlaying(
        currentMusic: currentMusic,
        queue: _queue,
        isPlaying: _audioPlayer.playing,
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
      emit(MusicPlaying(
        currentMusic: _queue[_currentIndex],
        queue: _queue,
        isPlaying: _audioPlayer.playing,
        currentIndex: _currentIndex,
        isLoop: _isLoop,
        isShuffle: _isShuffle,
      ));
    } else {
      _audioPlayer.play();
      emit(MusicPlaying(
        currentMusic: _queue[_currentIndex],
        queue: _queue,
        isPlaying: _audioPlayer.playing,
        currentIndex: _currentIndex,
        isLoop: _isLoop,
        isShuffle: _isShuffle,
      ));
    }
  }

  Future<void> next() async {
    if (_queue.isEmpty || _queue.length == _currentIndex + 1) return;

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
    if (_queue.isEmpty || _currentIndex == 0) return;

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
      isPlaying: _audioPlayer.playing,
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
      isPlaying: _audioPlayer.playing,
      isLoop: _isLoop,
      isShuffle: _isShuffle,
    ));
  }

  void stop() {
    _audioPlayer.stop();
    _queue.clear();
    _currentIndex = 0;
    _isLoop = false;
    _isShuffle = false;
    themeCubit.updatePrimaryColor(Colors.white);
    
    emit(MusicStopped());
  }

  @override
  Future<void> close() {
    _audioPlayer.dispose();
    _queue.clear();

    return super.close();
  }
}
