import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/config/api_config.dart';
import 'package:lyria/app/core/connectivity/connectivity_cubit.dart';
import 'package:lyria/app/core/services/cache/offline_media_cache.dart';
import 'package:lyria/app/core/services/http/my_http_client.dart';
import 'package:lyria/app/modules/bottom_sheet_options/page/music_options_sheet.dart';
import 'package:lyria/app/modules/common/music_tile.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_cubit.dart';

class GenrePage extends StatefulWidget {
  final String genre;
  const GenrePage({super.key, required this.genre});

  @override
  State<GenrePage> createState() => _GenrePageState();
}

class _GenrePageState extends State<GenrePage> {
  final MusicCubit musicCubit = getIt<MusicCubit>();
  final MyHttpClient http = getIt<MyHttpClient>();
  final OfflineMediaCache offlineCache = getIt<OfflineMediaCache>();

  List<Map<String, dynamic>> artists = [];
  List<Music> musics = [];
  List<Map<String, dynamic>> albums = [];
  bool isLoading = true;
  Set<String> downloadedIds = {};

  @override
  void initState() {
    super.initState();
    _loadGenre();
  }

  Future<void> _loadGenre() async {
    try {
      final response = await http.get('/genre/${widget.genre}');
      if (response['status'] == 200) {
        final data = Map<String, dynamic>.from(response['data'] as Map);
        await offlineCache.saveGenre(widget.genre, data);
        await _applyGenreData(data);
        return;
      }
    } catch (e) {
      // Falls back to offline cache below.
    }

    final cached = await offlineCache.getGenre(widget.genre) ??
        await offlineCache.buildGenreFromDownloads(widget.genre);
    if (cached != null) {
      await _applyGenreData(cached);
      return;
    }

    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _applyGenreData(Map<String, dynamic> data) async {
    final ids = await offlineCache.getDownloadedIds();
    final normalizedGenre = widget.genre.trim().toLowerCase();
    final downloadedGenreMusics = (await offlineCache.getDownloadedMusics())
        .where((music) => music.genre.toLowerCase().contains(normalizedGenre))
        .toList();
    final loadedMusics = (data['musics'] as List? ?? [])
        .map((m) => Music.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList();
    final loadedIds = loadedMusics.map((music) => music.id).toSet();
    for (final music in downloadedGenreMusics) {
      if (!loadedIds.contains(music.id)) {
        loadedMusics.add(music);
      }
    }
    final loadedArtists = (data['artists'] as List? ?? [])
        .map((a) => Map<String, dynamic>.from(a as Map))
        .toList();
    final loadedArtistIds =
        loadedArtists.map((artist) => artist['_id']?.toString()).toSet();
    final loadedAlbums = (data['albums'] as List? ?? [])
        .map((a) => Map<String, dynamic>.from(a as Map))
        .toList();
    final loadedAlbumIds =
        loadedAlbums.map((album) => album['_id']?.toString()).toSet();
    for (final music in downloadedGenreMusics) {
      if (!loadedArtistIds.contains(music.artistId)) {
        loadedArtists.add({
          '_id': music.artistId,
          'name': music.artistName,
          'avatarUrl': music.coverUrl,
          'genres': [music.genre],
        });
        loadedArtistIds.add(music.artistId);
      }
      if (music.albumId.isNotEmpty && !loadedAlbumIds.contains(music.albumId)) {
        loadedAlbums.add({
          '_id': music.albumId,
          'name': music.albumName,
          'albumCoverUrl': music.coverUrl,
          'artistId': music.artistId,
          'artistName': music.artistName,
          'color': music.color,
        });
        loadedAlbumIds.add(music.albumId);
      }
    }
    if (!mounted) return;
    setState(() {
      artists = loadedArtists;
      musics = loadedMusics;
      albums = loadedAlbums;
      downloadedIds = ids;
      isLoading = false;
    });
  }

  bool _isMusicAvailable(Music music, bool isOnline) {
    return isOnline || downloadedIds.contains(music.id);
  }

  bool _artistHasDownloadedMusic(String artistId) {
    return musics.any(
      (music) => music.artistId == artistId && downloadedIds.contains(music.id),
    );
  }

  bool _albumHasDownloadedMusic(String albumId) {
    return musics.any(
      (music) => music.albumId == albumId && downloadedIds.contains(music.id),
    );
  }

  void _playFromIndex(int index, bool isOnline) {
    final music = musics[index];
    if (!_isMusicAvailable(music, isOnline)) return;
    final playable = isOnline
        ? musics
        : musics.where((item) => downloadedIds.contains(item.id)).toList();
    final playableIndex = playable.indexWhere((item) => item.id == music.id);
    if (playableIndex >= 0) {
      musicCubit.setQueue(playable, playableIndex, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return BlocBuilder<ConnectivityCubit, bool>(
      bloc: getIt<ConnectivityCubit>(),
      builder: (context, isOnline) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  context.pop();
                } else {
                  context.go('/auth/ui/explorer');
                }
              },
            ),
            title: Text(
              widget.genre,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (artists.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          "Artistas",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 130,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: artists.length,
                            itemBuilder: (context, index) {
                              final artist = artists[index];
                              final avatarUrl =
                                  ApiConfig.fixImageUrl(artist['avatarUrl']);
                              final name = artist['name'] ?? '';
                              final artistId = artist['_id']?.toString() ?? '';
                              final available = isOnline ||
                                  _artistHasDownloadedMusic(artistId);

                              return GestureDetector(
                                onTap: () {
                                  if (available) {
                                    context.push('/auth/ui/artist',
                                        extra: artistId);
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 20),
                                  child: Opacity(
                                    opacity: available ? 1 : 0.35,
                                    child: Column(
                                      children: [
                                        ClipOval(
                                          child: Container(
                                            width: 90,
                                            height: 90,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            child: avatarUrl.isNotEmpty
                                                ? CachedNetworkImage(
                                                    imageUrl: avatarUrl,
                                                    fit: BoxFit.cover,
                                                    placeholder: (_, __) =>
                                                        const Icon(Icons.person,
                                                            color:
                                                                Colors.white54,
                                                            size: 40),
                                                    errorWidget: (_, __, ___) =>
                                                        const Icon(Icons.person,
                                                            color:
                                                                Colors.white54,
                                                            size: 40),
                                                  )
                                                : const Icon(Icons.person,
                                                    color: Colors.white54,
                                                    size: 40),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: 90,
                                          child: Text(
                                            name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      if (albums.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          "Álbuns",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: albums.length,
                            itemBuilder: (context, index) {
                              final album = albums[index];
                              final coverUrl =
                                  ApiConfig.fixImageUrl(album['albumCoverUrl']);
                              final albumName = album['name'] ?? '';
                              final albumId = album['_id']?.toString() ?? '';
                              final available =
                                  isOnline || _albumHasDownloadedMusic(albumId);

                              return GestureDetector(
                                onTap: () {
                                  if (available) {
                                    context.push('/auth/ui/album',
                                        extra: albumId);
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 16),
                                  child: Opacity(
                                    opacity: available ? 1 : 0.35,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Container(
                                            width: 150,
                                            height: 150,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            child: coverUrl.isNotEmpty
                                                ? CachedNetworkImage(
                                                    imageUrl: coverUrl,
                                                    fit: BoxFit.cover,
                                                    placeholder: (_, __) =>
                                                        const SizedBox.shrink(),
                                                    errorWidget: (_, __, ___) =>
                                                        const Icon(Icons.album,
                                                            color:
                                                                Colors.white54,
                                                            size: 40),
                                                  )
                                                : const Icon(Icons.album,
                                                    color: Colors.white54,
                                                    size: 40),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: 150,
                                          child: Text(
                                            albumName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      if (musics.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          "Músicas",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(
                          musics.length,
                          (index) {
                            final music = musics[index];
                            final available =
                                _isMusicAvailable(music, isOnline);
                            return MusicTile(
                              title: music.name,
                              subtitle: music.artistName,
                              image: music.coverUrl,
                              isRound: false,
                              enabled: available,
                              onTap: () => _playFromIndex(index, isOnline),
                              onLongPress: () =>
                                  showMusicOptionsSheet(context, music),
                              trailing: null,
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
