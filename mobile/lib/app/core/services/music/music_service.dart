import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';

class MusicService extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<Music> _queue = [];
  int _currentIndex = 0;
  bool _isLoop = false;
  bool _isShuffle = false;

  List<Music> get actualQueue => _queue;
  int get currentIndex => _currentIndex;
  bool get isLoop => _isLoop;
  bool get isShuffle => _isShuffle;
  Stream<Duration> get rawPositionStream => _audioPlayer.positionStream;

  MusicService() {
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

    _audioPlayer.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        _onSongComplete();
      }
    });

    _audioPlayer.durationStream.listen((duration) {
      final currentItem = mediaItem.value;
      if (currentItem != null && duration != null) {
        mediaItem.add(currentItem.copyWith(duration: duration));
      }
    });
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

  Future<void> setQueue(List<Music> queue, int currentIndex) async {
    _queue = queue;
    _currentIndex = currentIndex;
    final mediaItems = _queue.map((music) => _convertMusicToMediaItem(music)).toList();
    updateQueue(mediaItems);
    await _playCurrent();
  }

  Future<void> addToQueue(Music music) async {
    _queue.add(music);
    final newItem = _convertMusicToMediaItem(music);
    final updatedQueue = List<MediaItem>.from(queue.value)..add(newItem);
    updateQueue(updatedQueue);
    if (_queue.length == 1) {
      _currentIndex = 0;
      await _playCurrent();
    }
  }

  Future<void> removeFromQueue(Music music) async {
    int index = _queue.indexWhere((m) => m.id == music.id);
    if (index != -1) {
      _queue.removeAt(index);
      final updatedQueue = _queue.map((m) => _convertMusicToMediaItem(m)).toList();
      updateQueue(updatedQueue);
      if (_currentIndex >= _queue.length) {
        _currentIndex = _queue.length - 1;
      }
      await _playCurrent();
    }
  }

  Future<void> clearQueue() async {
    _queue.clear();
    _currentIndex = 0;
    updateQueue([]);
    await _playCurrent();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    _currentIndex = index;
    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    if (_queue.isEmpty) {
      stop();
      return;
    }
    final currentMusic = _queue[_currentIndex];
    mediaItem.add(_convertMusicToMediaItem(currentMusic));
    try {
      await _audioPlayer.setUrl(currentMusic.url);
      _audioPlayer.play();
    } catch (e) {
      // TODO: tratar erro
    }
  }

  @override
  Future<void> play() async {
    _audioPlayer.play();
  }

  @override
  Future<void> pause() async {
    _audioPlayer.pause();
  }

  @override
  Future<void> skipToNext() async {
    if (_queue.isEmpty || _queue.length == _currentIndex + 1) {
      return;
    }
    if (_isLoop) {
      await _playCurrent();
    } else if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      await _playCurrent();
    } else {
      stop();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_queue.isEmpty || _currentIndex == 0) return;
    if (_currentIndex > 0) {
      _currentIndex--;
      await _playCurrent();
    } else {
      await _playCurrent();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> toggleLoop() async {
    _isLoop = !_isLoop;
  }

  Future<void> toggleShuffle() async {
    _isShuffle = !_isShuffle;
    if (_isShuffle) {
      List<Music> tempQueue = _queue.sublist(_currentIndex + 1);
      tempQueue.shuffle(Random());
      _queue = _queue.sublist(0, _currentIndex + 1) + tempQueue;
      updateQueue(_queue.map((m) => _convertMusicToMediaItem(m)).toList());
    }
  }

  void _onSongComplete() async {
    if (_queue.isEmpty) return;

    if (_isLoop) {
      await _playCurrent();
      return;
    }

    if (_isShuffle) {
      List<Music> nextSongs = _queue.sublist(_currentIndex + 1);
      nextSongs.shuffle(Random());
      _queue = _queue.sublist(0, _currentIndex + 1) + nextSongs;
      updateQueue(_queue.map((m) => _convertMusicToMediaItem(m)).toList());
    }

    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      await _playCurrent();
    } else {
      _currentIndex = 0;
      await _playCurrent();
      pause();
    }
  }

  @override
  Future<void> stop() async {
    await _audioPlayer.stop();
    _queue.clear();
    _currentIndex = 0;
    _isLoop = false;
    _isShuffle = false;
    updateQueue([]);
    return super.stop();
  }

  MediaItem _convertMusicToMediaItem(Music music) {
    return MediaItem(
      id: music.id,
      album: music.albumName,
      title: music.name,
      artist: music.artistName,
      artUri: Uri.parse(music.coverUrl),
      extras: {
        'url': music.url,
        'color': music.color,
      },
    );
  }
}
