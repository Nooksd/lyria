import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/assets/custom_container.dart';
import 'package:lyria/app/modules/assets/seek_tile.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_cubit.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_states.dart';
import 'package:lyria/app/modules/music/presentation/includes/lyrics_tile.dart';

class MusicPage extends StatefulWidget {
  const MusicPage({super.key});

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> {
  final MusicCubit cubit = getIt<MusicCubit>();
  var _isLyricsExpanded = false;
  final ScrollController _lyricsScrollController = ScrollController();

  void _onPlayPause() {
    cubit.playPause();
  }

  void _onSkip() {
    cubit.next();
  }

  void _onReturn() {
    cubit.previous();
  }

  void _onLoop() {
    cubit.toggleLoop();
  }

  void _onShuffle() {
    cubit.toggleShuffle();
  }

  String formatDuration(Duration? duration) {
    if (duration == null) return "00:00";

    int minutes = duration.inMinutes;
    int seconds = duration.inSeconds.remainder(60);

    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  void _onDragEnd(DragEndDetails details) {
    if (details.velocity.pixelsPerSecond.dx > 1000) {
      cubit.next();
    } else if (details.velocity.pixelsPerSecond.dx < -1000) {
      cubit.previous();
    }
  }

  void _openLyrics() {
    setState(() {
      _isLyricsExpanded = !_isLyricsExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return BlocConsumer<MusicCubit, MusicState>(
      bloc: cubit,
      listener: (context, state) {
        if (state is! MusicPlaying) {
          context.pop();
        }
      },
      builder: (context, state) {
        if (_isLyricsExpanded && state is MusicPlaying) {
          return Scaffold(
            body: SizedBox(
              width: screenWidth,
              height: screenHeight,
              child: LyricsTile(
                lyrics: state.currentMusic.lyrics,
                positionStream: cubit.positionStream,
                scrollController: _lyricsScrollController,
                close: () {
                  setState(() {
                    _isLyricsExpanded = false;
                  });
                },
                isFullScreen: true,
              ),
            ),
          );
        }

        if (state is MusicPlaying) {
          final music = state.currentMusic;
          final isPlaying = state.isPlaying;
          final isLoop = state.isLoop;
          final isShuffle = state.isShuffle;
          final lyrics = music.lyrics;

          return Scaffold(
            body: CustomContainer(
              width: screenWidth,
              height: screenHeight,
              child: SafeArea(
                child: SingleChildScrollView(
                  physics: lyrics != null
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  child: Column(
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
                        padding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.05),
                        child: SizedBox(
                          height: 30,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 25,
                                height: 30,
                                child: IconButton(
                                  onPressed: () => context.pop(),
                                  icon: Icon(
                                    CustomIcons.goback,
                                    size: 25,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              Text(
                                music.albumName,
                                style: TextStyle(
                                  fontSize: 20,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
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
                      SizedBox(height: 40),
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _onPlayPause,
                              onHorizontalDragEnd: _onDragEnd,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  width: screenWidth * 0.76,
                                  height: screenWidth * 0.76,
                                  decoration: BoxDecoration(
                                    image: DecorationImage(
                                      image: NetworkImage(music.coverUrl),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 30),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: screenWidth * 0.6,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Text(
                                        music.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 22,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                        ),
                                      ),
                                      Text(
                                        music.artistName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Spacer(),
                                GestureDetector(
                                  onTap: () {},
                                  child: Icon(
                                    CustomIcons.heart_outline,
                                    size: 22,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                SizedBox(width: 20),
                                GestureDetector(
                                  onTap: () {},
                                  child: Icon(
                                    CustomIcons.download,
                                    size: 22,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 40),
                            SizedBox(
                              width: screenWidth * 0.76,
                              height: 50,
                              child: SeekTile(),
                            ),
                            SizedBox(height: 5),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.02,
                              ),
                              child: Row(
                                children: [
                                  StreamBuilder<Duration?>(
                                    stream: cubit.positionStream,
                                    builder: (context, snapshot) {
                                      final position =
                                          snapshot.data ?? Duration.zero;
                                      return Text(
                                        formatDuration(position),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                        ),
                                      );
                                    },
                                  ),
                                  Spacer(),
                                  StreamBuilder<Duration?>(
                                    stream: cubit.durationStream,
                                    builder: (context, snapshot) {
                                      final duration =
                                          snapshot.data ?? Duration.zero;
                                      return Text(
                                        formatDuration(duration),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 30),
                            SizedBox(
                              height: 60,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: _onShuffle,
                                    icon: Icon(
                                      CustomIcons.shuffle,
                                      size: 18,
                                      color: isShuffle
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _onReturn,
                                    icon: Icon(
                                      CustomIcons.return_icon,
                                      size: 18,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _onPlayPause,
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        borderRadius:
                                            BorderRadius.circular(100),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          isPlaying
                                              ? CustomIcons.pause
                                              : CustomIcons.play,
                                          size: 25,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _onSkip,
                                    icon: Icon(
                                      CustomIcons.skip,
                                      size: 18,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _onLoop,
                                    icon: Icon(
                                      CustomIcons.loop,
                                      size: 18,
                                      color: isLoop
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 25),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () {},
                                  icon: Icon(
                                    CustomIcons.devices,
                                    size: 22,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: screenWidth * 0.85,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 20,
                          ),
                          child: Column(
                            children: [
                              SizedBox(
                                height: 300,
                                child: LyricsTile(
                                  lyrics: state.currentMusic.lyrics,
                                  positionStream: cubit.positionStream,
                                  scrollController: _lyricsScrollController,
                                  close: _openLyrics,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return Container();
      },
    );
  }

  @override
  void dispose() {
    _lyricsScrollController.dispose();
    super.dispose();
  }
}
