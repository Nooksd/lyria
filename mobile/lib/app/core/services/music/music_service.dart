import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';

class MusicService extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ConcatenatingAudioSource _playlist =
      ConcatenatingAudioSource(children: []);

  bool _isLoop = false;
  bool _isShuffle = false;
  bool get isLoop => _isLoop;
  bool get isShuffle => _isShuffle;

  MusicService() {
    _init();
  }

  Future<void> _init() async {
    loadEmptyPlaylist();
    await _audioPlayer.setAudioSource(_playlist);
    _setupPlaybackListeners();
  }

  Future<void> loadEmptyPlaylist() async {
    try {
      await _audioPlayer.setAudioSource(_playlist);
    } catch (e) {
      print("Error: $e");
    }
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
        mediaItem.add(currentItem);
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

  MediaItem convertMusicToMediaItem(Music music) {
    return MediaItem(
      id: music.id,
      album: music.albumName,
      title: music.name,
      artist: music.artistName,
      artUri: Uri.parse(music.coverUrl),
      duration: const Duration(minutes: 5),
      extras: {
        'url': music.url,
        'color': music.color,
        'waveform': music.waveform,
        'lyrics': music.lyrics ?? [],
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
      lyrics: item.extras?['lyrics'] ?? [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> setQueue(List<Music> queue, int currentIndex) async {
    await _playlist.clear();
    for (final music in queue) {
      await _playlist.add(_createAudioSource(music));
    }
    await _audioPlayer.setAudioSource(_playlist, initialIndex: currentIndex);

    if (queue.isNotEmpty) {
      final firstItem = convertMusicToMediaItem(queue[currentIndex]);
      mediaItem.add(firstItem);
      print("Forçando atualização da música atual: ${firstItem.title}");
    }
  }

  AudioSource _createAudioSource(Music music) {
    return AudioSource.uri(
      Uri.parse(music.url),
      tag: convertMusicToMediaItem(music),
    );
  }

  Future<void> addToQueue(Music music) async {
    await _playlist.add(_createAudioSource(music));
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _playlist.children.length) return;
    await _playlist.removeAt(index);
  }

  Future<void> toggleLoop() async {
    _isLoop = !_isLoop;
    await _audioPlayer.setLoopMode(_isLoop ? LoopMode.all : LoopMode.off);
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
    await _playlist.clear();
    return super.stop();
  }

  @override
  Future<void> onNotificationDeleted() async {
    final isForeground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (isForeground) {
      playbackState.add(playbackState.value);
    } else {
      await stop();
    }
  }
}
