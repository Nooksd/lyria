import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_cubit.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_states.dart';

class QueueTile extends StatefulWidget {
  const QueueTile({super.key});

  @override
  State<QueueTile> createState() => _QueueTileState();
}

class _QueueTileState extends State<QueueTile> {
  final MusicCubit cubit = getIt<MusicCubit>();
  final PageController _pageController = PageController(viewportFraction: 0.6);
  int _lastKnownIndex = 0;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageController.jumpToPage(cubit.currentIndex);
      _lastKnownIndex = cubit.currentIndex;
    });

    _pageController.addListener(() {
      if (_pageController.page != null && !_isAnimating) {
        int newIndex = _pageController.page!.round();
        if (cubit.currentIndex != newIndex) {
          cubit.skipToIndex(newIndex);
        }
      }
    });
  }

  void _onPlayPause() {
    cubit.playPause();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return BlocBuilder<MusicCubit, MusicState>(
      bloc: cubit,
      builder: (context, state) {
        if (state is MusicPlaying) {
          if (state.currentIndex != _lastKnownIndex) {
            _lastKnownIndex = state.currentIndex;
            _isAnimating = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _pageController
                  .animateToPage(
                state.currentIndex,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
              )
                  .then((_) {
                _isAnimating = false;
              });
            });
          }
          final queue = state.queue;
          final isPlaying = state.isPlaying;

          return Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Fila de reprodução",
                      style: TextStyle(fontSize: 20),
                    ),
                    Text(
                      "${state.currentIndex + 1}/${queue.length}",
                      style: const TextStyle(fontSize: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: screenWidth,
                height: 200,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: queue.length,
                  pageSnapping: true,
                  padEnds: true,
                  itemBuilder: (context, index) {
                    double scale = index == state.currentIndex ? 1.1 : 0.85;

                    return TweenAnimationBuilder(
                      duration: const Duration(milliseconds: 300),
                      tween: Tween<double>(begin: scale, end: scale),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value as double,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                GestureDetector(
                                  onTap: _onPlayPause,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Image.network(
                                      queue[index].coverUrl,
                                      width: 170,
                                      height: 170,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                if (index != state.currentIndex)
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                            sigmaX: 2, sigmaY: 2),
                                        child: SizedBox(),
                                      ),
                                    ),
                                  ),
                                if (index == state.currentIndex && !isPlaying)
                                  Positioned.fill(
                                    child: GestureDetector(
                                      onTap: _onPlayPause,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(
                                            sigmaX: 1,
                                            sigmaY: 1,
                                          ),
                                          child: Center(
                                            child: Icon(
                                              CustomIcons.play,
                                              size: 50,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              SizedBox(height: 70),
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
