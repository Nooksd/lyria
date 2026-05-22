import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/config/api_config.dart';
import 'package:lyria/app/core/connectivity/connectivity_cubit.dart';
import 'package:lyria/app/core/services/cache/favorites_cache.dart';
import 'package:lyria/app/core/services/cache/offline_media_cache.dart';
import 'package:lyria/app/modules/bottom_sheet_options/page/music_options_sheet.dart';
import 'package:lyria/app/modules/common/music_tile.dart';
import 'package:lyria/app/modules/download/presentation/cubits/download_cubit.dart';
import 'package:lyria/app/modules/download/presentation/cubits/download_states.dart';
import 'package:lyria/app/modules/favorites/domain/entities/favorite_album.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_cubit.dart';
import 'package:lyria/app/core/services/http/my_http_client.dart';

class AlbumPage extends StatefulWidget {
  final String albumId;
  final Music? seedMusic;
  const AlbumPage({super.key, required this.albumId, this.seedMusic});

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  final MusicCubit musicCubit = getIt<MusicCubit>();
  final MyHttpClient http = getIt<MyHttpClient>();
  final DownloadCubit downloadCubit = getIt<DownloadCubit>();
  final FavoritesCache favoritesCache = getIt<FavoritesCache>();
  final OfflineMediaCache offlineCache = getIt<OfflineMediaCache>();

  Map<String, dynamic>? album;
  List<Music> musics = [];
  bool isLoading = true;
  bool isFavorite = false;
  Set<String> downloadedIds = {};

  @override
  void initState() {
    super.initState();
    _loadAlbum();
  }

  Future<void> _loadAlbum() async {
    try {
      final response = await http.get('/album/${widget.albumId}');
      if (response['status'] == 200) {
        final data = Map<String, dynamic>.from(response['data'] as Map);
        await offlineCache.saveAlbum(widget.albumId, data);
        await _applyAlbumData(data);
        await _loadFavoriteState();
        return;
      }
    } catch (e) {
      // Falls back to offline cache below.
    }

    final cached = await offlineCache.getAlbum(widget.albumId);
    Map<String, dynamic>? fallback;
    if (cached != null && await _hasDownloadedMusic(cached)) {
      fallback = cached;
    }
    fallback ??= await offlineCache.buildAlbumFromDownloads(widget.albumId);
    fallback ??= _buildAlbumFromSeed();
    if (fallback != null) {
      await _applyAlbumData(fallback);
      await _loadFavoriteState();
      return;
    }

    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _applyAlbumData(Map<String, dynamic> data) async {
    final loadedMusics = (data['musics'] as List? ?? [])
        .map((m) => Music.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList();
    final ids = await offlineCache.getDownloadedIds();
    if (!mounted) return;
    setState(() {
      album = Map<String, dynamic>.from(data['album'] as Map? ?? {});
      album!['artistName'] = data['artistName'] ?? album!['artistName'] ?? '';
      musics = loadedMusics;
      downloadedIds = ids;
      isLoading = false;
    });
    downloadCubit.loadPlaylistStatuses(musics.map((m) => m.id).toList());
  }

  Future<bool> _hasDownloadedMusic(Map<String, dynamic> data) async {
    final cachedMusics = (data['musics'] as List? ?? [])
        .map((m) => Music.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList();
    return offlineCache.hasDownloadedMusic(cachedMusics);
  }

  Map<String, dynamic>? _buildAlbumFromSeed() {
    final music = widget.seedMusic;
    if (music == null ||
        music.albumId.isEmpty ||
        music.albumId != widget.albumId) {
      return null;
    }

    return {
      'album': {
        '_id': music.albumId,
        'name': music.albumName,
        'artistId': music.artistId,
        'artistName': music.artistName,
        'albumCoverUrl': music.coverUrl,
        'color': music.color,
        'totalTracks': 1,
      },
      'artistName': music.artistName,
      'musics': [music.toJson()],
    };
  }

  Future<void> _loadFavoriteState() async {
    final favorites = await favoritesCache.fetchAndCacheFavoriteAlbums();
    if (!mounted) return;
    setState(() {
      isFavorite = favorites.any((item) => item.id == widget.albumId);
    });
  }

  Future<void> _toggleFavoriteAlbum() async {
    if (album == null) return;
    final favorites = await favoritesCache.getCachedFavoriteAlbums();
    final updated = await favoritesCache.toggleAlbumFavorite(
      _currentFavoriteAlbum(),
      favorites,
    );
    if (!mounted) return;
    setState(() {
      isFavorite = updated.any((item) => item.id == widget.albumId);
    });
  }

  FavoriteAlbum _currentFavoriteAlbum() {
    return FavoriteAlbum(
      id: widget.albumId,
      name: album!['name'] as String? ?? '',
      artistId: album!['artistId'] as String? ?? '',
      artistName: album!['artistName'] as String? ?? '',
      albumCoverUrl: ApiConfig.fixImageUrl(album!['albumCoverUrl'] as String?),
      color: album!['color'] as String? ?? '',
      musicCount: musics.length,
      totalTracks: (album!['totalTracks'] as num?)?.toInt() ?? musics.length,
      releaseDate: album!['releaseDate'] as String? ?? '',
    );
  }

  bool _isMusicAvailable(Music music, bool isOnline) {
    final status = downloadCubit.state[music.id];
    return isOnline ||
        downloadedIds.contains(music.id) ||
        status == DownloadStatus.downloaded;
  }

  List<Music> _playableMusics(bool isOnline) {
    if (isOnline) return musics;
    return musics.where((music) => _isMusicAvailable(music, isOnline)).toList();
  }

  void _playFromIndex(int index, bool isOnline) {
    final music = musics[index];
    if (!_isMusicAvailable(music, isOnline)) return;
    final playable = _playableMusics(isOnline);
    final playableIndex = playable.indexWhere((item) => item.id == music.id);
    if (playableIndex >= 0) {
      musicCubit.setQueue(playable, playableIndex, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    if (album == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: Text("Álbum não encontrado")),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final coverUrl = ApiConfig.fixImageUrl(album!['albumCoverUrl']);
    final name = album!['name'] ?? '';
    final artistName = album!['artistName'] ?? '';
    final artistId = album!['artistId'] ?? '';
    final rawColor = album!['color'] ?? '';
    final color = rawColor.replaceAll('#', '');

    return BlocBuilder<ConnectivityCubit, bool>(
      bloc: getIt<ConnectivityCubit>(),
      builder: (context, isOnline) {
        return BlocBuilder<DownloadCubit, Map<String, DownloadStatus>>(
          bloc: downloadCubit,
          builder: (context, downloadState) {
            return Scaffold(
              body: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 350,
                    pinned: true,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.pop(),
                    ),
                    actions: [
                      IconButton(
                        onPressed: _toggleFavoriteAlbum,
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                        ),
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  color.isNotEmpty && color.length == 6
                                      ? Color(int.parse('0xFF$color'))
                                          .withValues(alpha: 0.6)
                                      : Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.6),
                                  Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                ],
                              ),
                            ),
                          ),
                          Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.only(top: 60, bottom: 20),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      width: 200,
                                      height: 200,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      child: coverUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: coverUrl,
                                              fit: BoxFit.cover,
                                              fadeInDuration: Duration.zero,
                                              fadeOutDuration: Duration.zero,
                                              placeholder: (_, __) =>
                                                  const SizedBox.shrink(),
                                              errorWidget: (_, __, ___) =>
                                                  const Icon(Icons.album,
                                                      size: 80,
                                                      color: Colors.white54),
                                            )
                                          : const Icon(Icons.album,
                                              size: 80, color: Colors.white54),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  GestureDetector(
                                    onTap: () {
                                      if (artistId.isNotEmpty) {
                                        context.push('/auth/ui/artist',
                                            extra: artistId);
                                      }
                                    },
                                    child: Text(
                                      artistName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.7),
                                      ),
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
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.05, vertical: 16),
                      child: Row(
                        children: [
                          SizedBox(
                            height: 48,
                            width: 48,
                            child: IconButton(
                              onPressed: () {
                                if (musics.isNotEmpty) {
                                  final playable = isOnline
                                      ? musics
                                      : _playableMusics(isOnline);
                                  if (playable.isNotEmpty) {
                                    musicCubit.setQueue(playable, 0, null);
                                  }
                                }
                              },
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                              ),
                              icon: Icon(
                                Icons.play_arrow,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            height: 48,
                            width: 48,
                            child: IconButton(
                              onPressed: () {
                                if (musics.isNotEmpty) {
                                  final playable = isOnline
                                      ? musics
                                      : _playableMusics(isOnline);
                                  if (playable.isNotEmpty) {
                                    final shuffled = List<Music>.from(playable)
                                      ..shuffle();
                                    musicCubit.setQueue(shuffled, 0, null);
                                  }
                                }
                              },
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                              ),
                              icon: Icon(
                                Icons.shuffle,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          _AlbumDownloadButton(musics: musics),
                          const Spacer(),
                          Text(
                            "${musics.length} música${musics.length != 1 ? 's' : ''}",
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final music = musics[index];
                        final available = _isMusicAvailable(music, isOnline);

                        return Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.05),
                          child: MusicTile(
                            title: music.name,
                            subtitle: artistName,
                            image: music.coverUrl,
                            isRound: false,
                            enabled: available,
                            onTap: () => _playFromIndex(index, isOnline),
                            onLongPress: () =>
                                showMusicOptionsSheet(context, music),
                            trailing: null,
                          ),
                        );
                      },
                      childCount: musics.length,
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 120),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AlbumDownloadButton extends StatelessWidget {
  final List<Music> musics;

  const _AlbumDownloadButton({required this.musics});

  @override
  Widget build(BuildContext context) {
    final downloadCubit = getIt<DownloadCubit>();

    return BlocBuilder<DownloadCubit, Map<String, DownloadStatus>>(
      bloc: downloadCubit,
      builder: (context, state) {
        final ids = musics.map((music) => music.id).toList();
        final status = downloadCubit.getPlaylistStatus(ids);

        switch (status) {
          case PlaylistDownloadStatus.downloading:
            return const SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            );
          case PlaylistDownloadStatus.downloaded:
            return SizedBox(
              height: 48,
              width: 48,
              child: IconButton(
                onPressed: null,
                icon: Icon(
                  Icons.download_done,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            );
          case PlaylistDownloadStatus.notDownloaded:
          default:
            return SizedBox(
              height: 48,
              width: 48,
              child: IconButton(
                onPressed: musics.isEmpty
                    ? null
                    : () => downloadCubit.downloadPlaylist(musics),
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
                icon: Icon(
                  Icons.download,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            );
        }
      },
    );
  }
}
