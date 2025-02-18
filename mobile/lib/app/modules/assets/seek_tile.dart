import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_cubit.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_states.dart';

class SeekTile extends StatefulWidget {
  const SeekTile({super.key});

  @override
  State<SeekTile> createState() => _SeekTileState();
}

class _SeekTileState extends State<SeekTile> {
  final MusicCubit cubit = getIt<MusicCubit>();

  double? _localPercentage;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MusicCubit, MusicState>(
      bloc: cubit,
      builder: (context, state) {
        if (state is MusicPlaying) {
          return GestureDetector(
            onHorizontalDragUpdate: (details) {
              final RenderBox containerBox =
                  context.findRenderObject() as RenderBox;
              final localPosition =
                  containerBox.globalToLocal(details.globalPosition);

              final double percentage =
                  (localPosition.dx / containerBox.size.width).clamp(0.0, 1.0);
              setState(() {
                _localPercentage = percentage;
              });
            },
            onHorizontalDragEnd: (details) {
              if (state.currentMusic.waveform.isNotEmpty) {
                final totalDuration = cubit.duration.inMilliseconds;
                final finalPercentage = _localPercentage ?? 0.0;
                final newPosition = Duration(
                    milliseconds: (totalDuration * finalPercentage).toInt());
                cubit.seekTo(newPosition);
              }
              setState(() {
                _localPercentage = null;
              });
            },
            onHorizontalDragCancel: () {
              setState(() {
                _localPercentage = null;
              });
            },
            child: SizedBox.expand(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: StreamBuilder<Duration?>(
                    stream: cubit.positionStream,
                    builder: (context, snapshot) {
                      final currentPosition =
                          snapshot.data?.inMilliseconds ?? 0;
                      final totalDuration = cubit.duration.inMilliseconds;
                      final progressPercentage = _localPercentage ??
                          (totalDuration > 0
                              ? currentPosition / totalDuration
                              : 0.0);

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          state.currentMusic.waveform.length,
                          (index) {
                            final containerPercentage =
                                1 / state.currentMusic.waveform.length;
                            final barPosition = index * containerPercentage;
                            const toleranceFactor = 0.5;
                            final tolerance =
                                containerPercentage * toleranceFactor;

                            final isBeforeCurrentPosition =
                                barPosition <= progressPercentage;
                            final isActualBar = barPosition >=
                                    progressPercentage - tolerance &&
                                barPosition <= progressPercentage + tolerance;

                            return Container(
                              width: 2.5,
                              height: 45 *
                                  (state.currentMusic.waveform[index] == 1
                                      ? 1.0
                                      : state.currentMusic.waveform[index] *
                                          0.7),
                              color: isActualBar
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(
                                        alpha:
                                            isBeforeCurrentPosition ? 1.0 : 0.3,
                                      ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
