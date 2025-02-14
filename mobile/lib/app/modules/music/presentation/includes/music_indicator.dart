import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_cubit.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_states.dart';

class MusicIndicator extends StatefulWidget {
  const MusicIndicator({super.key});

  @override
  State<MusicIndicator> createState() => _MusicIndicatorState();
}

class _MusicIndicatorState extends State<MusicIndicator> {
  double _offsetX = 0.0;
  final double _dragThreshold = 80.0;

  final MusicCubit cubit = getIt<MusicCubit>();

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _offsetX += details.primaryDelta!;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_offsetX.abs() > _dragThreshold) {
      cubit.stop();
      _offsetX = 0;
    }

    setState(() {
      _offsetX = 0;
    });
  }

  void _onPlayPause() {
    cubit.playPause();
  }

  void _onSkip() {
    cubit.next();
  }

  void _onReturn() {
    cubit.previous();
  }

  void _openMusicPage() {
    context.push('/auth/music');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return BlocBuilder<MusicCubit, MusicState>(
      bloc: cubit,
      builder: (context, state) {
        if (state is MusicPlaying) {
          final currentMusic = state.currentMusic;
          final isPlaying = state.isPlaying;

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
            child: GestureDetector(
              onTap: _openMusicPage,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                transform: Matrix4.translationValues(_offsetX, 0, 0),
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: Container(
                            width: 45,
                            height: 45,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              image: DecorationImage(
                                image: NetworkImage(currentMusic.coverUrl),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                currentMusic.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                currentMusic.artistName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimary
                                      .withValues(alpha: 0.6),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _onReturn,
                          icon: Icon(
                            CustomIcons.return_icon,
                            size: 15,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                        IconButton(
                          onPressed: _onPlayPause,
                          icon: Icon(
                            isPlaying ? CustomIcons.pause : CustomIcons.play,
                            size: 18,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                        IconButton(
                          onPressed: _onSkip,
                          icon: Icon(
                            CustomIcons.skip,
                            size: 15,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }
}
