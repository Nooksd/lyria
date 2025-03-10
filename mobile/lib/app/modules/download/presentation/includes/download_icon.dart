import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/download/presentation/cubits/download_cubit.dart';
import 'package:lyria/app/modules/download/presentation/cubits/download_states.dart';

class DownloadIcon extends StatelessWidget {
  final DownloadCubit downloadCubit = getIt<DownloadCubit>();
  final String musicId;
  final double width;
  final double height;

  DownloadIcon({
    super.key,
    required this.musicId,
    this.width = 22,
    this.height = 22,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DownloadCubit, Map<String, DownloadStatus>>(
      bloc: downloadCubit,
      builder: (context, state) {
        final status = state[musicId] ?? DownloadStatus.notDownloaded;
        switch (status) {
          case DownloadStatus.downloading:
            return DownloadIconAnimated(width: width, height: height);
          case DownloadStatus.downloaded:
            return Icon(
              CustomIcons.downloaded,
              size: width,
              color: Theme.of(context).colorScheme.primary,
            );
          case DownloadStatus.error:
            return Icon(
              Icons.error,
              size: width,
              color: Colors.red,
            );
          case DownloadStatus.notDownloaded:
          default:
            return Icon(
              CustomIcons.download,
              size: width,
              color: Theme.of(context).colorScheme.onPrimary,
            );
        }
      },
    );
  }
}

class DownloadIconAnimated extends StatefulWidget {
  final double width;
  final double height;

  const DownloadIconAnimated({
    super.key,
    this.width = 22,
    this.height = 22,
  });

  @override
  DownloadIconAnimatedState createState() => DownloadIconAnimatedState();
}

class DownloadIconAnimatedState extends State<DownloadIconAnimated>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _animation,
      child: Icon(
        CustomIcons.download,
        size: widget.width,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }
}
