import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/core/services/connectivity/connectivity_service.dart';
import 'package:lyria/app/modules/common/music_tile.dart';
import 'package:lyria/app/modules/download/presentation/cubits/download_cubit.dart';
import 'package:lyria/app/modules/download/presentation/cubits/download_states.dart';
import 'package:lyria/app/modules/explorer/presentation/cubits/search_cubit.dart';
import 'package:lyria/app/modules/library/domain/entities/playlist.dart';
import 'package:lyria/app/modules/library/presentation/cubits/playlist_cubit.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_cubit.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_states.dart';

class PlaylistControl extends StatefulWidget {
  final Playlist playlist;
  final Function(Playlist) onPlaylistUpdated;

  const PlaylistControl({
    super.key,
    required this.playlist,
    required this.onPlaylistUpdated,
  });

  @override
  State<PlaylistControl> createState() => _PlaylistControlState();
}

class _PlaylistControlState extends State<PlaylistControl> {
  final MusicCubit musicCubit = getIt<MusicCubit>();
  final DownloadCubit downloadCubit = getIt<DownloadCubit>();
  final PlaylistCubit playlistCubit = getIt<PlaylistCubit>();
  final SearchCubit searchCubit = getIt<SearchCubit>();

  void _playPlaylist() async {
    await musicCubit.setQueue(widget.playlist.musics, 0, widget.playlist.id);
  }

  void _stopPlaylist() async {
    await musicCubit.stop();
  }

  void _sharePlaylist() async {
    final link = 'lyria://playlist/${widget.playlist.id}';
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copiado!')),
      );
    }
  }

  void _addMusic() {
    _showAddMusicSheet();
  }

  void _showAddMusicSheet() {
    final queryController = TextEditingController();
    List<dynamic> results = [];
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (_, scrollController) => Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(sheetCtx).colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: queryController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Buscar música...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (val) async {
                      if (val.trim().isEmpty) {
                        setSheetState(() => results = []);
                        return;
                      }
                      setSheetState(() => isLoading = true);
                      final res = await searchCubit.search(val.trim());
                      setSheetState(() {
                        isLoading = false;
                        results = res
                            .where(
                                (s) => s.type == 'music' && s.music != null)
                            .toList();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: results.length,
                        itemBuilder: (_, i) {
                          final search = results[i];
                          final alreadyAdded = widget.playlist.musics
                              .any((m) => m.id == search.id);
                          return MusicTile(
                            title: search.name,
                            subtitle: search.description,
                            image: search.imageUrl,
                            isRound: false,
                            onTap: alreadyAdded
                                ? () {}
                                : () async {
                                    final isOnline = getIt<ConnectivityService>().isOnline;
                                    final wasFullyDownloaded =
                                        downloadCubit.getPlaylistStatus(
                                              widget.playlist.musics
                                                  .map((m) => m.id)
                                                  .toList(),
                                            ) ==
                                            PlaylistDownloadStatus.downloaded;
                                    Navigator.pop(sheetCtx);
                                    final updated =
                                        await playlistCubit.addMusicToPlaylist(
                                      widget.playlist,
                                      search.music!,
                                    );
                                    if (updated != null) {
                                      if (wasFullyDownloaded && isOnline) {
                                        final alreadyDownloaded =
                                            downloadCubit.state[search.music!.id] ==
                                                DownloadStatus.downloaded;
                                        if (!alreadyDownloaded) {
                                          downloadCubit
                                              .downloadMusic(search.music!);
                                        }
                                      }
                                      widget.onPlaylistUpdated(updated);
                                    }
                                  },
                            onLongPress: () {},
                            trailing: alreadyAdded
                                ? Icon(Icons.check,
                                    color: Theme.of(sheetCtx)
                                        .colorScheme
                                        .primary)
                                : null,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _toogleScheffle() async {
    musicCubit.toggleShuffle();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MusicCubit, MusicState>(
      bloc: musicCubit,
      builder: (context, state) {
        final isCurrentPlaylist =
            musicCubit.currentPlaylistId == widget.playlist.id;
        final isShuffle = state is MusicPlaying && state.isShuffle;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            PlaylistDownloadButton(playlist: widget.playlist),
            IconButton(
              onPressed: _sharePlaylist,
              icon: Icon(
                CustomIcons.share,
                color: Theme.of(context).colorScheme.onSurface,
                size: 20,
              ),
            ),
            IconButton(
              onPressed: _addMusic,
              icon: Icon(
                CustomIcons.plus,
                color: Theme.of(context).colorScheme.onSurface,
                size: 20,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: _toogleScheffle,
              icon: Icon(
                CustomIcons.shuffle,
                color: isShuffle
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () =>
                  isCurrentPlaylist ? _stopPlaylist() : _playPlaylist(),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCurrentPlaylist ? Icons.square : CustomIcons.play,
                  size: 20,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class PlaylistDownloadButton extends StatefulWidget {
  final Playlist playlist;

  const PlaylistDownloadButton({super.key, required this.playlist});

  @override
  State<PlaylistDownloadButton> createState() =>
      _PlaylistDownloadButtonState();
}

class _PlaylistDownloadButtonState extends State<PlaylistDownloadButton> {
  final DownloadCubit downloadCubit = getIt<DownloadCubit>();

  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  @override
  void didUpdateWidget(covariant PlaylistDownloadButton old) {
    super.didUpdateWidget(old);
    if (old.playlist.musics.length != widget.playlist.musics.length) {
      _loadStatuses();
    }
  }

  Future<void> _loadStatuses() async {
    final ids = widget.playlist.musics.map((m) => m.id).toList();
    await downloadCubit.loadPlaylistStatuses(ids);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DownloadCubit, Map<String, DownloadStatus>>(
      bloc: downloadCubit,
      builder: (context, state) {
        final ids = widget.playlist.musics.map((m) => m.id).toList();
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
            return IconButton(
              onPressed: null,
              icon: Icon(
                CustomIcons.downloaded,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            );
          case PlaylistDownloadStatus.notDownloaded:
          default:
            return IconButton(
              onPressed: widget.playlist.musics.isEmpty
                  ? null
                  : () => downloadCubit.downloadPlaylist(widget.playlist.musics),
              icon: Icon(
                CustomIcons.download,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            );
        }
      },
    );
  }
}

