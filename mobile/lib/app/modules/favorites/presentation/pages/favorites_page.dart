import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/connectivity/connectivity_cubit.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/core/services/cache/favorites_cache.dart';
import 'package:lyria/app/modules/bottom_sheet_options/page/music_options_sheet.dart';
import 'package:lyria/app/modules/common/music_tile.dart';
import 'package:lyria/app/modules/download/presentation/cubits/download_cubit.dart';
import 'package:lyria/app/modules/download/presentation/cubits/download_states.dart';
import 'package:lyria/app/modules/favorites/domain/entities/favorite_album.dart';
import 'package:lyria/app/modules/favorites/domain/entities/favorite_artist.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_cubit.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final MusicCubit musicCubit = getIt<MusicCubit>();
  final FavoritesCache favoritesCache = getIt<FavoritesCache>();
  final DownloadCubit downloadCubit = getIt<DownloadCubit>();

  List<Music> favorites = [];
  List<FavoriteAlbum> favoriteAlbums = [];
  List<FavoriteArtist> favoriteArtists = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final cachedMusics = await favoritesCache.getCachedFavorites();
      final cachedAlbums = await favoritesCache.getCachedFavoriteAlbums();
      final cachedArtists = await favoritesCache.getCachedFavoriteArtists();
      if (mounted) {
        setState(() {
          favorites = cachedMusics;
          favoriteAlbums = cachedAlbums;
          favoriteArtists = cachedArtists;
          isLoading = false;
        });
      }

      final results = await Future.wait([
        favoritesCache.fetchAndCacheFavorites(),
        favoritesCache.fetchAndCacheFavoriteAlbums(),
        favoritesCache.fetchAndCacheFavoriteArtists(),
      ]);

      if (mounted) {
        setState(() {
          favorites = results[0] as List<Music>;
          favoriteAlbums = results[1] as List<FavoriteAlbum>;
          favoriteArtists = results[2] as List<FavoriteArtist>;
        });
        downloadCubit.loadPlaylistStatuses(favorites.map((m) => m.id).toList());
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _toggleFavorite(int index) async {
    final updated = await favoritesCache.removeFavorite(index, favorites);
    setState(() {
      favorites = updated;
    });
  }

  Future<void> _toggleAlbumFavorite(int index) async {
    final updated =
        await favoritesCache.removeFavoriteAlbum(index, favoriteAlbums);
    setState(() {
      favoriteAlbums = updated;
    });
  }

  Future<void> _toggleArtistFavorite(int index) async {
    final updated =
        await favoritesCache.removeFavoriteArtist(index, favoriteArtists);
    setState(() {
      favoriteArtists = updated;
    });
  }

  bool _isMusicAvailable(Music music, bool isOnline) {
    final status = downloadCubit.state[music.id];
    return isOnline || status == DownloadStatus.downloaded;
  }

  void _playAll(bool isOnline) {
    if (favorites.isEmpty) return;
    final playable = isOnline
        ? favorites
        : favorites.where((m) => _isMusicAvailable(m, isOnline)).toList();
    if (playable.isNotEmpty) musicCubit.setQueue(playable, 0, null);
  }

  void _shuffle(bool isOnline) {
    if (favorites.isEmpty) return;
    final playable = isOnline
        ? favorites
        : favorites.where((m) => _isMusicAvailable(m, isOnline)).toList();
    if (playable.isNotEmpty) {
      final shuffled = List<Music>.from(playable)..shuffle();
      musicCubit.setQueue(shuffled, 0, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return BlocBuilder<ConnectivityCubit, bool>(
      bloc: getIt<ConnectivityCubit>(),
      builder: (context, isOnline) {
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
              title: Row(
                children: [
                  const Text("Favoritos"),
                  if (!isOnline) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.cloud_off, size: 16, color: Colors.grey),
                  ],
                ],
              ),
              bottom: TabBar(
                indicatorColor: primary,
                labelColor: primary,
                tabs: const [
                  Tab(text: 'Músicas'),
                  Tab(text: 'Álbuns'),
                  Tab(text: 'Artistas'),
                ],
              ),
            ),
            body: isLoading
                ? Center(child: CircularProgressIndicator(color: primary))
                : TabBarView(
                    children: [
                      _buildMusicTab(isOnline),
                      _buildAlbumsTab(isOnline),
                      _buildArtistsTab(isOnline),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildMusicTab(bool isOnline) {
    final screenWidth = MediaQuery.of(context).size.width;
    final primary = Theme.of(context).colorScheme.primary;

    return RefreshIndicator(
      color: Theme.of(context).colorScheme.onPrimary,
      backgroundColor: primary,
      onRefresh: _loadFavorites,
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 8),
          if (favorites.isEmpty)
            _emptyState(CustomIcons.heart_outline, 'Nenhuma música favorita')
          else ...[
            Text(
              '${favorites.length} música${favorites.length != 1 ? 's' : ''}',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _playAll(isOnline),
                    icon: Icon(CustomIcons.play, size: 16),
                    label: const Text("Tocar"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      foregroundColor: primary,
                      side: BorderSide(color: primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _shuffle(isOnline),
                    icon: Icon(CustomIcons.shuffle, size: 16),
                    label: const Text("Aleatório"),
                    style: OutlinedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      foregroundColor: primary,
                      side: BorderSide(color: primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...favorites.asMap().entries.map((entry) {
              final index = entry.key;
              final music = entry.value;
              final available = _isMusicAvailable(music, isOnline);

              return Opacity(
                opacity: available ? 1.0 : 0.4,
                child: MusicTile(
                  title: music.name,
                  subtitle: music.artistName,
                  image: music.coverUrl,
                  isRound: false,
                  enabled: available,
                  onTap: available
                      ? () => musicCubit.setQueue(favorites, index, null)
                      : () {},
                  onLongPress: available
                      ? () => showMusicOptionsSheet(context, music)
                      : () {},
                  trailing: IconButton(
                    icon: Icon(Icons.favorite, color: primary),
                    onPressed: () => _toggleFavorite(index),
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildAlbumsTab(bool isOnline) {
    final screenWidth = MediaQuery.of(context).size.width;
    final primary = Theme.of(context).colorScheme.primary;

    return RefreshIndicator(
      color: Theme.of(context).colorScheme.onPrimary,
      backgroundColor: primary,
      onRefresh: _loadFavorites,
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 8),
          if (favoriteAlbums.isEmpty)
            _emptyState(Icons.album_outlined, 'Nenhum álbum favorito')
          else ...[
            Text(
              '${favoriteAlbums.length} álbum${favoriteAlbums.length != 1 ? 's' : ''}',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            ...favoriteAlbums.asMap().entries.map((entry) {
              final index = entry.key;
              final album = entry.value;
              final count =
                  album.musicCount > 0 ? album.musicCount : album.totalTracks;

              return MusicTile(
                title: album.name,
                subtitle:
                    '${album.artistName}${count > 0 ? ' • $count música${count != 1 ? 's' : ''}' : ''}',
                image: album.albumCoverUrl,
                isRound: false,
                enabled: isOnline,
                onTap: isOnline
                    ? () => context.push('/auth/ui/album', extra: album.id)
                    : () {},
                onLongPress: () {},
                trailing: IconButton(
                  icon: Icon(Icons.favorite, color: primary),
                  onPressed: () => _toggleAlbumFavorite(index),
                ),
              );
            }),
          ],
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildArtistsTab(bool isOnline) {
    final screenWidth = MediaQuery.of(context).size.width;
    final primary = Theme.of(context).colorScheme.primary;

    return RefreshIndicator(
      color: Theme.of(context).colorScheme.onPrimary,
      backgroundColor: primary,
      onRefresh: _loadFavorites,
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 8),
          if (favoriteArtists.isEmpty)
            _emptyState(Icons.person_outline, 'Nenhum artista favorito')
          else ...[
            Text(
              '${favoriteArtists.length} artista${favoriteArtists.length != 1 ? 's' : ''}',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            ...favoriteArtists.asMap().entries.map((entry) {
              final index = entry.key;
              final artist = entry.value;

              return MusicTile(
                title: artist.name,
                subtitle:
                    '${artist.albumCount} álbum${artist.albumCount != 1 ? 's' : ''} • ${artist.musicCount} música${artist.musicCount != 1 ? 's' : ''}',
                image: artist.avatarUrl,
                isRound: true,
                enabled: isOnline,
                onTap: isOnline
                    ? () => context.push('/auth/ui/artist', extra: artist.id)
                    : () {},
                onLongPress: () {},
                trailing: IconButton(
                  icon: Icon(Icons.favorite, color: primary),
                  onPressed: () => _toggleArtistFavorite(index),
                ),
              );
            }),
          ],
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _emptyState(IconData icon, String message) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.55,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 60,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
