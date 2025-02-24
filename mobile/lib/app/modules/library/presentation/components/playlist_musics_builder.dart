import 'package:flutter/material.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/common/music_tile.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_cubit.dart';

class PlaylistMusicsBuilder extends StatefulWidget {
  final List<Music> musics;
  final String playlistId;

  const PlaylistMusicsBuilder(
      {super.key, required this.playlistId, required this.musics});

  @override
  State<PlaylistMusicsBuilder> createState() => _PlaylistMusicsBuilderState();
}

class _PlaylistMusicsBuilderState extends State<PlaylistMusicsBuilder> {
  final MusicCubit musicCubit = getIt<MusicCubit>();
  late Future<void> _initialFuture;

  @override
  void initState() {
    super.initState();
    _initialFuture = Future.delayed(Duration.zero);
  }

  void _playPlaylistFromIndex(int index) {
    musicCubit.setQueue(widget.musics, index, widget.playlistId);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.musics.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text("Adicionar Músicas"),
        ),
      );
    }

    return FutureBuilder(
      future: _initialFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.musics.length,
          itemBuilder: (context, index) {
            return MusicTile(
              title: widget.musics[index].name,
              subtitle: widget.musics[index].artistName,
              image: widget.musics[index].coverUrl,
              isRound: false,
              onTap: () => _playPlaylistFromIndex(index),
              trailing: IconButton(
                onPressed: () {},
                icon: Icon(
                  CustomIcons.dots,
                  size: 20,
                ),
              ),
              onLongPress: () {},
            );
          },
        );
      },
    );
  }
}
