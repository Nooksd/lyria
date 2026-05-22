import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/config/api_config.dart';
import 'package:lyria/app/core/connectivity/connectivity_cubit.dart';
import 'package:lyria/app/core/services/cache/favorites_cache.dart';
import 'package:lyria/app/core/services/cache/offline_media_cache.dart';
import 'package:lyria/app/core/services/http/my_http_client.dart';
import 'package:lyria/app/modules/bottom_sheet_options/page/music_options_sheet.dart';
import 'package:lyria/app/modules/common/music_tile.dart';
import 'package:lyria/app/modules/favorites/domain/entities/favorite_artist.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_cubit.dart';

class ArtistPage extends StatefulWidget {
  final String artistId;
  const ArtistPage({super.key, required this.artistId});

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  final MusicCubit musicCubit = getIt<MusicCubit>();
  final MyHttpClient http = getIt<MyHttpClient>();
  final FavoritesCache favoritesCache = getIt<FavoritesCache>();
  final OfflineMediaCache offlineCache = getIt<OfflineMediaCache>();

  Map<String, dynamic>? artist;
  List<Music> topMusics = [];
  List<Music> singles = [];
  List<Map<String, dynamic>> albums = [];
  bool isLoading = true;
  bool isFavorite = false;
  Set<String> downloadedIds = {};

  @override
  void initState() {
    super.initState();
    _loadArtist();
  }

  Future<void> _loadArtist() async {
    try {
      final response = await http.get('/artist/${widget.artistId}');
      if (response['status'] == 200) {
        final data = Map<String, dynamic>.from(response['data'] as Map);
        await offlineCache.saveArtist(widget.artistId, data);
        await _applyArtistData(data);
        await _loadFavoriteState();
        return;
      }
    } catch (e) {
      // Falls back to offline cache below.
    }

    final cached = await offlineCache.getArtist(widget.artistId);
    final fallback = cached != null && await _hasDownloadedMusic(cached)
        ? cached
        : await offlineCache.buildArtistFromDownloads(widget.artistId);
    if (fallback != null) {
      await _applyArtistData(fallback);
      await _loadFavoriteState();
      return;
    }

    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _applyArtistData(Map<String, dynamic> data) async {
    final loadedTopMusics = (data['musics'] as List? ?? [])
        .map((m) => Music.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList();
    final loadedSingles = (data['singles'] as List? ?? [])
        .map((m) => Music.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList();
    final ids = await offlineCache.getDownloadedIds();
    if (!mounted) return;
    setState(() {
      artist = Map<String, dynamic>.from(data['artist'] as Map? ?? {});
      topMusics = loadedTopMusics;
      singles = loadedSingles;
      albums = (data['albums'] as List? ?? [])
          .map((a) => Map<String, dynamic>.from(a as Map))
          .toList();
      downloadedIds = ids;
      isLoading = false;
    });
  }

  Future<bool> _hasDownloadedMusic(Map<String, dynamic> data) async {
    final cachedMusics = [
      ...(data['musics'] as List? ?? []),
      ...(data['singles'] as List? ?? []),
    ].map((m) => Music.fromJson(Map<String, dynamic>.from(m as Map))).toList();
    return offlineCache.hasDownloadedMusic(cachedMusics);
  }

  Future<void> _loadFavoriteState() async {
    final favorites = await favoritesCache.fetchAndCacheFavoriteArtists();
    if (!mounted) return;
    setState(() {
      isFavorite = favorites.any((item) => item.id == widget.artistId);
    });
  }

  Future<void> _toggleFavoriteArtist() async {
    if (artist == null) return;
    final favorites = await favoritesCache.getCachedFavoriteArtists();
    final updated = await favoritesCache.toggleArtistFavorite(
      _currentFavoriteArtist(),
      favorites,
    );
    if (!mounted) return;
    setState(() {
      isFavorite = updated.any((item) => item.id == widget.artistId);
    });
  }

  FavoriteArtist _currentFavoriteArtist() {
    return FavoriteArtist(
      id: widget.artistId,
      name: artist!['name'] as String? ?? '',
      avatarUrl: ApiConfig.fixImageUrl(artist!['avatarUrl'] as String?),
      bannerUrl: ApiConfig.fixImageUrl(artist!['bannerUrl'] as String?),
      bio: artist!['bio'] as String? ?? '',
      color: artist!['color'] as String? ?? '',
      genres:
          (artist!['genres'] as List?)?.map((e) => e.toString()).toList() ?? [],
      musicCount: topMusics.length + singles.length,
      albumCount: albums.length,
      spotifyPopularity: (artist!['spotifyPopularity'] as num?)?.toInt() ?? 0,
      spotifyFollowers: (artist!['spotifyFollowers'] as num?)?.toInt() ?? 0,
    );
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.transparent;
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('0xFF$clean'));
    }
    return Colors.transparent;
  }

  bool _isMusicAvailable(Music music, bool isOnline) {
    return isOnline || downloadedIds.contains(music.id);
  }

  bool _albumHasDownloadedMusic(String albumId) {
    return [...topMusics, ...singles].any(
      (music) => music.albumId == albumId && downloadedIds.contains(music.id),
    );
  }

  void _playFromList(List<Music> source, int index, bool isOnline) {
    final music = source[index];
    if (!_isMusicAvailable(music, isOnline)) return;
    final playable = isOnline
        ? source
        : source.where((item) => downloadedIds.contains(item.id)).toList();
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

    if (artist == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: Text("Artista não encontrado")),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final avatarUrl = ApiConfig.fixImageUrl(artist!['avatarUrl']);
    final bannerUrl = ApiConfig.fixImageUrl(artist!['bannerUrl']);
    final name = artist!['name'] ?? '';
    final bio = artist!['bio'] ?? '';
    final rawColor = artist!['color'] ?? '';
    final artistColor = _parseColor(rawColor);
    final hasColor = artistColor != Colors.transparent;
    final accentColor =
        hasColor ? artistColor : Theme.of(context).colorScheme.primary;
    final bgColor = Theme.of(context).colorScheme.primaryContainer;

    return BlocBuilder<ConnectivityCubit, bool>(
      bloc: getIt<ConnectivityCubit>(),
      builder: (context, isOnline) {
        return Scaffold(
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner + avatar + back button (like profile page)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Banner
                    Container(
                      width: screenWidth,
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accentColor,
                            accentColor.withValues(alpha: 0.6),
                            bgColor,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: bannerUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: bannerUrl,
                              fit: BoxFit.cover,
                              fadeInDuration: Duration.zero,
                              fadeOutDuration: Duration.zero,
                              placeholder: (_, __) => const SizedBox.shrink(),
                              errorWidget: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            )
                          : null,
                    ),
                    // Back button
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      left: 8,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => context.pop(),
                      ),
                    ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      right: 8,
                      child: IconButton(
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: Colors.white,
                        ),
                        onPressed: _toggleFavoriteArtist,
                      ),
                    ),
                    // Avatar
                    Positioned(
                      bottom: -50,
                      left: screenWidth / 2 - 55,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: bgColor, width: 4),
                        ),
                        child: ClipOval(
                          child: Container(
                            width: 106,
                            height: 106,
                            color: Theme.of(context).colorScheme.primary,
                            child: avatarUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: avatarUrl,
                                    fit: BoxFit.cover,
                                    fadeInDuration: Duration.zero,
                                    fadeOutDuration: Duration.zero,
                                    placeholder: (_, __) => const Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Colors.white54),
                                    errorWidget: (_, __, ___) => const Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Colors.white54),
                                  )
                                : const Icon(Icons.person,
                                    size: 50, color: Colors.white54),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 60),

                // Name
                Center(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Bio
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
                      child: Text(
                        bio,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                ],

                // Genres
                if (artist!['genres'] != null &&
                    (artist!['genres'] as List).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children:
                          (artist!['genres'] as List).map<Widget>((genre) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            genre.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                // Top musics
                if (topMusics.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                    child: const Text(
                      "Músicas populares",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...topMusics.take(5).toList().asMap().entries.map((entry) {
                    final index = entry.key;
                    final music = entry.value;
                    final available = _isMusicAvailable(music, isOnline);
                    return Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                      child: MusicTile(
                        title: music.name,
                        subtitle: music.albumName,
                        image: music.coverUrl,
                        isRound: false,
                        enabled: available,
                        onTap: () => _playFromList(topMusics, index, isOnline),
                        onLongPress: () =>
                            showMusicOptionsSheet(context, music),
                        trailing: null,
                      ),
                    );
                  }),
                ],

                // Albums
                if (albums.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                    child: const Text(
                      "Álbuns",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.only(left: screenWidth * 0.05),
                      itemCount: albums.length,
                      itemBuilder: (context, index) {
                        final album = albums[index];
                        final coverUrl =
                            ApiConfig.fixImageUrl(album['albumCoverUrl']);
                        final albumName = album['name'] ?? '';
                        final albumId = album['_id']?.toString() ?? '';
                        final albumColorRaw = album['color'] ?? '';
                        final albumColor = _parseColor(albumColorRaw);
                        final hasAlbumColor = albumColor != Colors.transparent;
                        final placeholderColor =
                            hasAlbumColor ? albumColor : accentColor;
                        final available =
                            isOnline || _albumHasDownloadedMusic(albumId);

                        return GestureDetector(
                          onTap: () {
                            if (available) {
                              context.push('/auth/ui/album', extra: albumId);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Opacity(
                              opacity: available ? 1 : 0.35,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: 150,
                                      height: 150,
                                      color: placeholderColor,
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
                                                      color: Colors.white54,
                                                      size: 40),
                                            )
                                          : const Icon(Icons.album,
                                              color: Colors.white54, size: 40),
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

                // Singles
                if (singles.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                    child: const Text(
                      "Singles",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...singles.asMap().entries.map((entry) {
                    final index = entry.key;
                    final music = entry.value;
                    final available = _isMusicAvailable(music, isOnline);
                    return Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                      child: MusicTile(
                        title: music.name,
                        subtitle: music.artistName,
                        image: music.coverUrl,
                        isRound: false,
                        enabled: available,
                        onTap: () => _playFromList(singles, index, isOnline),
                        onLongPress: () =>
                            showMusicOptionsSheet(context, music),
                        trailing: null,
                      ),
                    );
                  }),
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
