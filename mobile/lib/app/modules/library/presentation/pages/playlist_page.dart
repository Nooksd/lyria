import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/common/custom_container.dart';
import 'package:lyria/app/modules/common/music_tile.dart';
import 'package:lyria/app/modules/library/domain/entities/playlist.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_cubit.dart';

class PlaylistPage extends StatefulWidget {
  final Playlist playlist;

  const PlaylistPage({super.key, required this.playlist});

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  final MusicCubit musicCubit = getIt<MusicCubit>();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    void playPlaylist() async {
      await musicCubit.setQueue(widget.playlist.musics, 0, widget.playlist.id);
      setState(() {});
    }

    void playPlaylistFromIndex(int index) {
      musicCubit.setQueue(widget.playlist.musics, index, widget.playlist.id);
      setState(() {});
    }

    return Scaffold(
      body: CustomContainer(
        width: screenWidth,
        height: screenHeight,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
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
                SizedBox(height: 30),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                  child: SizedBox(
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
                          child: Container(
                            width: screenWidth * 0.6,
                            height: screenWidth * 0.6,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: NetworkImage(widget.playlist.imageUrl),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 30,
                          height: 30,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 15),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        widget.playlist.name,
                        style: TextStyle(
                          fontSize: 20,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '${widget.playlist.musics.length} música${widget.playlist.musics.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      SizedBox(height: 15),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () {},
                            icon: Icon(
                              CustomIcons.download,
                              size: 20,
                            ),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: Icon(
                              CustomIcons.share,
                              size: 20,
                            ),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: Icon(
                              CustomIcons.plus,
                              size: 20,
                            ),
                          ),
                          Spacer(),
                          IconButton(
                            onPressed: () {},
                            icon: Icon(
                              CustomIcons.shuffle,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => musicCubit.currentPlaylistId ==
                                    widget.playlist.id
                                ? musicCubit.stop()
                                : playPlaylist(),
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                musicCubit.currentPlaylistId ==
                                        widget.playlist.id
                                    ? Icons.square
                                    : CustomIcons.play,
                                size: 20,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          )
                        ],
                      ),
                      SizedBox(height: 15),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: widget.playlist.musics.length,
                        itemBuilder: (context, index) {
                          return MusicTile(
                            title: widget.playlist.musics[index].name,
                            subtitle: widget.playlist.musics[index].artistName,
                            image: widget.playlist.musics[index].coverUrl,
                            isRound: false,
                            onTap: () => playPlaylistFromIndex(index),
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
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
