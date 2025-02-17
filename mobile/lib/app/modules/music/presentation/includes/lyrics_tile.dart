import 'package:flutter/material.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/music/domain/entities/lyrics.dart';

class LyricsTile extends StatelessWidget {
  final List<LyricLine>? lyrics;
  final Stream<Duration?> positionStream;
  final ScrollController scrollController;
  final VoidCallback close;
  final bool isFullScreen;

  const LyricsTile({
    super.key,
    required this.lyrics,
    required this.positionStream,
    required this.scrollController,
    required this.close,
    this.isFullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    if (lyrics == null) return Container();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: isFullScreen ? BorderRadius.zero : BorderRadius.circular(30),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isFullScreen ? 20 : 5,
            vertical: isFullScreen ? 20 : 0,
          ),
          child: Column(
            children: [
              SizedBox(
                height: 25,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Letra',
                      style: TextStyle(
                        fontSize: 20,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: close,
                      child: Container(
                        width: 25,
                        height: 25,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                        child: Icon(
                          isFullScreen ? CustomIcons.expand : CustomIcons.expand,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Expanded(
                child: StreamBuilder<Duration?>(
                  stream: positionStream,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
        
                    return ListView.builder(
                      controller: scrollController,
                      physics: const ClampingScrollPhysics(),
                      itemCount: lyrics!.length,
                      itemBuilder: (context, index) {
                        final lyricLine = lyrics![index];
                        final hasPassedLine = position >= lyricLine.timeAsDuration;
        
                        if (hasPassedLine &&
                            index < lyrics!.length - 1 &&
                            position < lyrics![index + 1].timeAsDuration) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            final desiredPosition = (index * 55.0);
                            final maxScroll = scrollController.position.maxScrollExtent;
                            final scrollPosition = desiredPosition.clamp(0.0, maxScroll);

                            scrollController.animateTo(
                              scrollPosition,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                            );
                          });
                        }
        
                        return SizedBox(
                          height: 55,
                          child: Text(
                            lyricLine.content,
                            style: TextStyle(
                              fontSize: 20,
                              color: hasPassedLine
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.primaryContainer,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}