import 'package:equatable/equatable.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';

abstract class MusicState extends Equatable {
  @override
  List<Object?> get props => [];
}

class MusicInitial extends MusicState {}

class MusicLoading extends MusicState {}

class MusicPlaying extends MusicState {
  final Music currentMusic;
  final List<Music> queue;
  final int currentIndex;
  final bool isPlaying;
  final bool isLoop;
  final bool isShuffle;

  MusicPlaying({
    required this.currentMusic,
    required this.queue,
    required this.currentIndex,
    required this.isPlaying,
    required this.isLoop,
    required this.isShuffle,
  });

  @override
  List<Object?> get props => [currentMusic, queue, currentIndex, isPlaying, isLoop, isShuffle];
}

class MusicStopped extends MusicState {}

class MusicError extends MusicState {
  final String message;
  MusicError(this.message);
}
