import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/core/services/cache/favorites_cache.dart';
import 'package:lyria/app/modules/common/custom_container.dart';
import 'package:lyria/app/modules/common/seek_tile.dart';
import 'package:lyria/app/modules/download/presentation/cubits/download_cubit.dart';
import 'package:lyria/app/modules/download/presentation/includes/download_icon.dart';
import 'package:lyria/app/modules/library/domain/entities/playlist.dart';
import 'package:lyria/app/modules/library/presentation/cubits/playlist_cubit.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_cubit.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_states.dart';
import 'package:lyria/app/modules/music/presentation/includes/lyrics_tile.dart';
import 'package:volume_controller/volume_controller.dart';

class MusicPage extends StatefulWidget {
  const MusicPage({super.key});

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> {
  final MusicCubit cubit = getIt<MusicCubit>();
  final DownloadCubit downloadCubit = getIt<DownloadCubit>();
  final PlaylistCubit playlistCubit = getIt<PlaylistCubit>();
  final FavoritesCache favoritesCache = getIt<FavoritesCache>();
  static const MethodChannel _audioRoutesChannel =
      MethodChannel('lyria/audio_routes');

  var _isLyricsExpanded = false;
  final ScrollController _lyricsScrollController = ScrollController();
  final Set<String> _favoritedIds = {};
  List<Music> _cachedFavorites = [];
  double _deviceVolume = 0;

  @override
  void initState() {
    super.initState();
    _loadFavoritedIds();
    _loadDeviceVolume();
  }

  Future<void> _loadFavoritedIds() async {
    final cached = await favoritesCache.getCachedFavorites();
    if (mounted) {
      setState(() {
        _cachedFavorites = cached;
        _favoritedIds.addAll(cached.map((m) => m.id));
      });
    }
  }

  void _onPlayPause() {
    cubit.playPause();
  }

  Future<void> _onFavoriteToggle(Music music) async {
    final wasFav = _favoritedIds.contains(music.id);
    setState(() {
      if (wasFav) {
        _favoritedIds.remove(music.id);
      } else {
        _favoritedIds.add(music.id);
      }
    });

    final updated =
        await favoritesCache.toggleFavorite(music, _cachedFavorites);
    if (mounted) {
      setState(() {
        _cachedFavorites = updated;
      });
    }
  }

  void _onDownload(Music music) {
    downloadCubit.downloadMusic(music);
  }

  Future<void> _loadDeviceVolume() async {
    final volume = await VolumeController.instance.getVolume();
    if (mounted) {
      setState(() => _deviceVolume = volume);
    }
  }

  Playlist? _currentPlaylist() {
    final playlistId = cubit.currentPlaylistId;
    if (playlistId.isEmpty) return null;
    for (final playlist in playlistCubit.playlists) {
      if (playlist.id == playlistId) return playlist;
    }
    return null;
  }

  String _contextTitle(Music music) {
    return _currentPlaylist()?.name ?? music.albumName;
  }

  void _openArtist(Music music) {
    if (music.artistId.isNotEmpty) {
      context.push('/auth/ui/artist', extra: music);
    }
  }

  void _openAlbumOrPlaylist(Music music) {
    final playlist = _currentPlaylist();
    if (playlist != null) {
      context.push('/auth/ui/playlist', extra: playlist);
      return;
    }
    if (music.albumId.isNotEmpty) {
      context.push('/auth/ui/album', extra: music);
    }
  }

  Future<void> _showDeviceSheet() async {
    await _loadDeviceVolume();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      useRootNavigator: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> setVolume(double value) async {
              await VolumeController.instance.setVolume(value);
              if (mounted) setState(() => _deviceVolume = value);
              setSheetState(() => _deviceVolume = value);
            }

            return SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Saida de audio',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final opened = await _audioRoutesChannel
                                    .invokeMethod<bool>('showRoutePicker') ??
                                false;
                            if (!opened && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Nenhum seletor de audio disponivel',
                                  ),
                                ),
                              );
                            }
                          } catch (_) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Nao foi possivel abrir os dispositivos',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.speaker_group_outlined),
                        label: const Text('Escolher dispositivo'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Icon(Icons.volume_down),
                        Expanded(
                          child: Slider(
                            value: _deviceVolume.clamp(0.0, 1.0).toDouble(),
                            onChanged: setVolume,
                          ),
                        ),
                        const Icon(Icons.volume_up),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showQueueSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Fila',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    Expanded(
                      child: BlocBuilder<MusicCubit, MusicState>(
                        bloc: cubit,
                        builder: (context, state) {
                          if (state is! MusicPlaying || state.queue.isEmpty) {
                            return const Center(
                              child: Text('Fila vazia'),
                            );
                          }

                          return ReorderableListView.builder(
                            scrollController: scrollController,
                            itemCount: state.queue.length,
                            onReorder: (oldIndex, newIndex) {
                              var targetIndex = newIndex;
                              if (oldIndex < targetIndex) targetIndex -= 1;
                              cubit.moveQueueItem(oldIndex, targetIndex);
                            },
                            itemBuilder: (context, index) {
                              final music = state.queue[index];
                              final isCurrent = index == state.currentIndex;

                              return ListTile(
                                key: ValueKey('queue_${music.id}_$index'),
                                contentPadding: EdgeInsets.zero,
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: music.coverUrl,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                title: Text(
                                  music.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  isCurrent
                                      ? 'Tocando agora'
                                      : music.artistName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: state.queue.length <= 1
                                          ? null
                                          : () => cubit.removeFromQueue(index),
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                    ),
                                    GestureDetector(
                                      onDoubleTap: () =>
                                          cubit.moveQueueItemNext(index),
                                      child: ReorderableDragStartListener(
                                        index: index,
                                        child: const Padding(
                                          padding: EdgeInsets.all(8),
                                          child: Icon(Icons.drag_handle),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _onSkip() {
    cubit.next();
  }

  void _onReturn() {
    cubit.previous();
  }

  void _onLoop() {
    cubit.toggleLoop();
  }

  void _onShuffle() {
    cubit.toggleShuffle();
  }

  String formatDuration(Duration? duration) {
    if (duration == null) return "00:00";

    int minutes = duration.inMinutes;
    int seconds = duration.inSeconds.remainder(60);

    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  void _onDragEnd(DragEndDetails details) {
    if (details.velocity.pixelsPerSecond.dx > 1000) {
      cubit.previous();
    } else if (details.velocity.pixelsPerSecond.dx < -1000) {
      cubit.next();
    }
  }

  void _openLyrics() {
    setState(() {
      _isLyricsExpanded = !_isLyricsExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return BlocConsumer<MusicCubit, MusicState>(
      bloc: cubit,
      listener: (context, state) {
        if (state is! MusicPlaying) {
          context.pop();
        }
      },
      builder: (context, state) {
        if (_isLyricsExpanded && state is MusicPlaying) {
          return Scaffold(
            body: SizedBox(
              width: screenWidth,
              height: screenHeight,
              child: LyricsTile(
                lyrics: state.currentMusic.lyrics,
                positionStream: cubit.positionStream,
                scrollController: _lyricsScrollController,
                close: () {
                  setState(() {
                    _isLyricsExpanded = false;
                  });
                },
                isFullScreen: true,
              ),
            ),
          );
        }

        if (state is MusicPlaying) {
          final music = state.currentMusic;
          final isPlaying = state.isPlaying;
          final isLoop = state.isLoop;
          final isShuffle = state.isShuffle;
          final lyrics = music.lyrics ?? [];

          return Scaffold(
            body: CustomContainer(
              width: screenWidth,
              height: screenHeight,
              child: SafeArea(
                child: SingleChildScrollView(
                  physics: lyrics.isNotEmpty
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      Center(
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            Image.asset(
                              'assets/images/logo.png',
                              color: Theme.of(context).colorScheme.primary,
                              width: 50,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 30),
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.05),
                        child: SizedBox(
                          height: 30,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 25,
                                height: 30,
                                child: IconButton(
                                  onPressed: () => context.pop(),
                                  icon: Icon(
                                    CustomIcons.goback,
                                    size: 25,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _openAlbumOrPlaylist(music),
                                child: Text(
                                  _contextTitle(music),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 20,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 30,
                                height: 30,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 40),
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _onPlayPause,
                              onHorizontalDragEnd: _onDragEnd,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: SizedBox(
                                  width: screenWidth * 0.76,
                                  height: screenWidth * 0.76,
                                  child: CachedNetworkImage(
                                    imageUrl: music.coverUrl,
                                    fit: BoxFit.cover,
                                    fadeInDuration: Duration.zero,
                                    fadeOutDuration: Duration.zero,
                                    placeholder: (_, __) => Container(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      child: const Icon(Icons.music_note,
                                          size: 80, color: Colors.white54),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 30),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: screenWidth * 0.6,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Text(
                                        music.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 22,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => _openArtist(music),
                                        child: Text(
                                          music.artistName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.6),
                                            decoration:
                                                TextDecoration.underline,
                                            decorationColor: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.4),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Spacer(),
                                GestureDetector(
                                  onTap: () => _onFavoriteToggle(music),
                                  child: Icon(
                                    _favoritedIds.contains(music.id)
                                        ? Icons.favorite
                                        : CustomIcons.heart_outline,
                                    size: 22,
                                    color: _favoritedIds.contains(music.id)
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                  ),
                                ),
                                SizedBox(width: 20),
                                GestureDetector(
                                  onTap: () => _onDownload(music),
                                  child: DownloadIcon(
                                      musicId: music.id, width: 22, height: 22),
                                ),
                              ],
                            ),
                            SizedBox(height: 40),
                            SizedBox(
                              width: screenWidth * 0.76,
                              height: 50,
                              child: SeekTile(),
                            ),
                            SizedBox(height: 5),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.02,
                              ),
                              child: Row(
                                children: [
                                  StreamBuilder<Duration?>(
                                    stream: cubit.positionStream,
                                    builder: (context, snapshot) {
                                      final position =
                                          snapshot.data ?? Duration.zero;
                                      return Text(
                                        formatDuration(position),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                        ),
                                      );
                                    },
                                  ),
                                  Spacer(),
                                  StreamBuilder<Duration?>(
                                    stream: cubit.durationStream,
                                    builder: (context, snapshot) {
                                      final duration =
                                          snapshot.data ?? Duration.zero;
                                      return Text(
                                        formatDuration(duration),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 30),
                            SizedBox(
                              height: 60,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: _onShuffle,
                                    icon: Icon(
                                      CustomIcons.shuffle,
                                      size: 18,
                                      color: isShuffle
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _onReturn,
                                    icon: Icon(
                                      CustomIcons.return_icon,
                                      size: 18,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _onPlayPause,
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        borderRadius:
                                            BorderRadius.circular(100),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          isPlaying
                                              ? CustomIcons.pause
                                              : CustomIcons.play,
                                          size: 25,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _onSkip,
                                    icon: Icon(
                                      CustomIcons.skip,
                                      size: 18,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _onLoop,
                                    icon: Icon(
                                      CustomIcons.loop,
                                      size: 18,
                                      color: isLoop
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 25),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  onPressed: _showDeviceSheet,
                                  icon: Icon(
                                    CustomIcons.devices,
                                    size: 22,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                IconButton(
                                  onPressed: _showQueueSheet,
                                  icon: Icon(
                                    Icons.queue_music,
                                    size: 24,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      if (lyrics.isNotEmpty)
                        Container(
                          width: screenWidth * 0.85,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 20,
                            ),
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 300,
                                  child: LyricsTile(
                                    lyrics: state.currentMusic.lyrics,
                                    positionStream: cubit.positionStream,
                                    scrollController: _lyricsScrollController,
                                    close: _openLyrics,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return Container();
      },
    );
  }

  @override
  void dispose() {
    _lyricsScrollController.dispose();
    super.dispose();
  }
}
