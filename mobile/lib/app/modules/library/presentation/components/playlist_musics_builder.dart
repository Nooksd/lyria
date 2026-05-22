import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/connectivity/connectivity_cubit.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/bottom_sheet_options/page/music_options_sheet.dart';
import 'package:lyria/app/modules/common/music_tile.dart';
import 'package:lyria/app/modules/download/presentation/cubits/download_cubit.dart';
import 'package:lyria/app/modules/download/presentation/cubits/download_states.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_cubit.dart';

class PlaylistMusicsBuilder extends StatefulWidget {
  final List<Music> musics;
  final String playlistId;
  final Function(String musicId)? onRemoveMusic;

  const PlaylistMusicsBuilder({
    super.key,
    required this.playlistId,
    required this.musics,
    this.onRemoveMusic,
  });

  @override
  State<PlaylistMusicsBuilder> createState() => _PlaylistMusicsBuilderState();
}

class _PlaylistMusicsBuilderState extends State<PlaylistMusicsBuilder> {
  final MusicCubit musicCubit = getIt<MusicCubit>();
  final DownloadCubit downloadCubit = getIt<DownloadCubit>();

  void _playPlaylistFromIndex(int index, bool isOnline) {
    final music = widget.musics[index];
    if (!_isMusicAvailable(music, isOnline)) return;
    final playable = isOnline
        ? widget.musics
        : widget.musics
            .where(
                (m) => downloadCubit.state[m.id] == DownloadStatus.downloaded)
            .toList();
    final playableIndex = playable.indexWhere((m) => m.id == music.id);
    if (playableIndex >= 0) {
      musicCubit.setQueue(playable, playableIndex, widget.playlistId);
    }
  }

  bool _isMusicAvailable(Music music, bool isOnline) {
    if (isOnline) return true;
    final status = downloadCubit.state[music.id];
    return status == DownloadStatus.downloaded;
  }

  void _showMusicOptions(BuildContext context, Music music) {
    showMusicOptionsSheet(
      context,
      music,
      extraActionsBuilder: (sheetContext) => [
        ListTile(
          leading: const Icon(Icons.remove_circle_outline, color: Colors.red),
          title: const Text(
            'Remover da playlist',
            style: TextStyle(color: Colors.red),
          ),
          onTap: () {
            Navigator.pop(sheetContext);
            widget.onRemoveMusic?.call(music.id);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.musics.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text("Adicionar Músicas"),
        ),
      );
    }

    return BlocBuilder<ConnectivityCubit, bool>(
      bloc: getIt<ConnectivityCubit>(),
      builder: (context, isOnline) {
        return BlocBuilder<DownloadCubit, Map<String, DownloadStatus>>(
          bloc: downloadCubit,
          builder: (context, downloadState) {
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.musics.length,
              itemBuilder: (context, index) {
                final music = widget.musics[index];
                final available = _isMusicAvailable(music, isOnline);
                return MusicTile(
                  title: music.name,
                  subtitle: music.artistName,
                  image: music.coverUrl,
                  isRound: false,
                  enabled: available,
                  onTap: () => _playPlaylistFromIndex(index, isOnline),
                  trailing: IconButton(
                    onPressed: available
                        ? () => _showMusicOptions(context, music)
                        : null,
                    icon: Icon(
                      CustomIcons.dots,
                      size: 20,
                    ),
                  ),
                  onLongPress: available
                      ? () => _showMusicOptions(context, music)
                      : () {},
                );
              },
            );
          },
        );
      },
    );
  }
}
