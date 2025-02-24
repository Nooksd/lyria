import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_cubit.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_states.dart';

class PlaylistControl extends StatefulWidget {
  final List<Music> musics;
  final String playlistId;

  const PlaylistControl({
    super.key,
    required this.playlistId,
    required this.musics,
  });

  @override
  State<PlaylistControl> createState() => _PlaylistControlState();
}

class _PlaylistControlState extends State<PlaylistControl> {
  final MusicCubit musicCubit = getIt<MusicCubit>();

  void _playPlaylist() async {
    await musicCubit.setQueue(widget.musics, 0, widget.playlistId);
  }

  void _stopPlaylist() async {
    await musicCubit.stop();
  }

  void _downloadMusics() async {}
  void _sharePlaylist() async {}

  void _addMusic() async {}
  void _toogleScheffle() async {
    musicCubit.toggleShuffle();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MusicCubit, MusicState>(
      bloc: musicCubit,
      builder: (context, state) {
        final isCurrentPlaylist =
            musicCubit.currentPlaylistId == widget.playlistId;
        final isShuffle = state is MusicPlaying ? state.isShuffle : false;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _downloadMusics,
              icon: Icon(
                CustomIcons.download,
                color: Theme.of(context).colorScheme.onSurface,
                size: 20,
              ),
            ),
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
            Spacer(),
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
            SizedBox(width: 10),
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
            )
          ],
        );
      },
    );
  }

  playPlaylist() {}
}
