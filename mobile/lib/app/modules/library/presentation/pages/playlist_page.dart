import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/common/custom_container.dart';
import 'package:lyria/app/modules/download/presentation/cubits/download_cubit.dart';
import 'package:lyria/app/modules/download/presentation/cubits/download_states.dart';
import 'package:lyria/app/modules/library/domain/entities/playlist.dart';
import 'package:lyria/app/modules/library/presentation/components/playlist_control.dart';
import 'package:lyria/app/modules/library/presentation/components/playlist_musics_builder.dart';
import 'package:lyria/app/modules/library/presentation/cubits/playlist_cubit.dart';

class PlaylistPage extends StatefulWidget {
  final Playlist playlist;

  const PlaylistPage({super.key, required this.playlist});

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  final PlaylistCubit playlistCubit = getIt<PlaylistCubit>();
  final DownloadCubit downloadCubit = getIt<DownloadCubit>();
  late Playlist _currentPlaylist;

  @override
  void initState() {
    super.initState();
    _currentPlaylist = widget.playlist;
  }

  void _onPlaylistUpdated(Playlist updated) {
    setState(() => _currentPlaylist = updated);
  }

  Future<void> _onRemoveMusic(String musicId) async {
    final wasFullyDownloaded =
        downloadCubit.getPlaylistStatus(
              _currentPlaylist.musics.map((m) => m.id).toList(),
            ) ==
            PlaylistDownloadStatus.downloaded;

    final updated = await playlistCubit.removeMusicFromPlaylist(
        _currentPlaylist, musicId);
    if (updated != null && mounted) {
      setState(() => _currentPlaylist = updated);
      if (wasFullyDownloaded) {
        downloadCubit.deleteMusic(musicId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: CustomContainer(
        width: screenWidth,
        height: screenHeight,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
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
              const SizedBox(height: 30),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 25,
                      height: 30,
                      child: IconButton(
                        onPressed: () => context.pop(),
                        icon: Icon(
                          CustomIcons.goback,
                          size: 25,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: screenWidth * 0.6,
                        height: screenWidth * 0.6,
                        child: _currentPlaylist.playlistCoverUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl:
                                    '${_currentPlaylist.playlistCoverUrl}?v=${playlistCubit.cacheBuster}',
                                cacheKey: _currentPlaylist.playlistCoverUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: Theme.of(context).colorScheme.primary,
                                  child: const Icon(CustomIcons.list,
                                      size: 60, color: Colors.white54),
                                ),
                              )
                            : Container(
                                color: Theme.of(context).colorScheme.primary,
                                child: const Icon(CustomIcons.list,
                                    size: 60, color: Colors.white54),
                              ),
                      ),
                    ),
                    const SizedBox(width: 30, height: 30),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      _currentPlaylist.name,
                      style: TextStyle(
                        fontSize: 20,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '${_currentPlaylist.musics.length} música${_currentPlaylist.musics.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 15),
                    PlaylistControl(
                      playlist: _currentPlaylist,
                      onPlaylistUpdated: _onPlaylistUpdated,
                    ),
                    const SizedBox(height: 15),
                    PlaylistMusicsBuilder(
                      musics: _currentPlaylist.musics,
                      playlistId: _currentPlaylist.id,
                      onRemoveMusic: _onRemoveMusic,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

