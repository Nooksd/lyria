import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/connectivity/connectivity_cubit.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/core/services/cache/favorites_cache.dart';
import 'package:lyria/app/modules/common/music_tile.dart';
import 'package:lyria/app/modules/download/presentation/cubits/download_cubit.dart';
import 'package:lyria/app/modules/download/presentation/cubits/download_states.dart';
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
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      // Load cached first, then fetch from server
      final cached = await favoritesCache.getCachedFavorites();
      if (mounted) {
        setState(() {
          favorites = cached;
          isLoading = false;
        });
      }

      final fresh = await favoritesCache.fetchAndCacheFavorites();
      if (mounted) {
        setState(() {
          favorites = fresh;
        });
        // Load download statuses
        downloadCubit
            .loadPlaylistStatuses(favorites.map((m) => m.id).toList());
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _toggleFavorite(int index) async {
    final updated = await favoritesCache.removeFavorite(index, favorites);
    setState(() {
      favorites = updated;
    });
  }

  bool _isMusicAvailable(Music music, bool isOnline) {
    final status = downloadCubit.state[music.id];
    return isOnline || status == DownloadStatus.downloaded;
  }

  void _playAll(bool isOnline) {
    if (favorites.isNotEmpty) {
      final playable = isOnline
          ? favorites
          : favorites
              .where((m) => _isMusicAvailable(m, isOnline))
              .toList();
      if (playable.isNotEmpty) musicCubit.setQueue(playable, 0, null);
    }
  }

  void _shuffle(bool isOnline) {
    if (favorites.isNotEmpty) {
      final playable = isOnline
          ? favorites
          : favorites
              .where((m) => _isMusicAvailable(m, isOnline))
              .toList();
      if (playable.isNotEmpty) {
        final shuffled = List<Music>.from(playable)..shuffle();
        musicCubit.setQueue(shuffled, 0, null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final primary = Theme.of(context).colorScheme.primary;

    return BlocBuilder<ConnectivityCubit, bool>(
      bloc: getIt<ConnectivityCubit>(),
      builder: (context, isOnline) {
        return Scaffold(
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
                  Icon(Icons.cloud_off, size: 16, color: Colors.grey),
                ],
              ],
            ),
          ),
          body: isLoading
              ? Center(child: CircularProgressIndicator(color: primary))
              : favorites.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CustomIcons.heart_outline,
                            size: 60,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Nenhuma música favorita",
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: Theme.of(context).colorScheme.onPrimary,
                      backgroundColor: primary,
                      onRefresh: _loadFavorites,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.05),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
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
                                      backgroundColor: primary,
                                      foregroundColor: Theme.of(context)
                                          .colorScheme
                                          .onPrimary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(25),
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
                                      foregroundColor: primary,
                                      side: BorderSide(color: primary),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(25),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: ListView.builder(
                                itemCount: favorites.length,
                                itemBuilder: (context, index) {
                                  final music = favorites[index];
                                  final available =
                                      _isMusicAvailable(music, isOnline);

                                  return Opacity(
                                    opacity: available ? 1.0 : 0.4,
                                    child: MusicTile(
                                      title: music.name,
                                      subtitle: music.artistName,
                                      image: music.coverUrl,
                                      isRound: false,
                                      onTap: available
                                          ? () => musicCubit.setQueue(
                                                favorites, index, null)
                                          : () {},
                                      onLongPress: () {},
                                      trailing: IconButton(
                                        icon: Icon(
                                          Icons.favorite,
                                          color: primary,
                                        ),
                                        onPressed: () =>
                                            _toggleFavorite(index),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
        );
      },
    );
  }
}
