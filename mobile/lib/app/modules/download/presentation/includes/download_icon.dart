import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/download/presentation/cubits/download_cubit.dart';
import 'package:lyria/app/modules/download/presentation/cubits/download_states.dart';

class DownloadIcon extends StatefulWidget {
  final String musicId;
  final double width;
  final double height;

  const DownloadIcon({
    super.key,
    required this.musicId,
    this.width = 22,
    this.height = 22,
  });

  @override
  State<DownloadIcon> createState() => _DownloadIconState();
}

class _DownloadIconState extends State<DownloadIcon> {
  final DownloadCubit downloadCubit = getIt<DownloadCubit>();

  @override
  void initState() {
    super.initState();
    downloadCubit.loadDownloadStatus(widget.musicId);
  }

  @override
  void didUpdateWidget(covariant DownloadIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.musicId != widget.musicId) {
      downloadCubit.loadDownloadStatus(widget.musicId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DownloadCubit, Map<String, DownloadStatus>>(
      bloc: downloadCubit,
      builder: (context, state) {
        final status = state[widget.musicId] ?? DownloadStatus.notDownloaded;
        switch (status) {
          case DownloadStatus.downloading:
            return DownloadIconAnimated(
              width: widget.width,
              height: widget.height,
            );
          case DownloadStatus.downloaded:
            return Icon(
              CustomIcons.downloaded,
              size: widget.width,
              color: Theme.of(context).colorScheme.primary,
            );
          case DownloadStatus.error:
            return Icon(
              Icons.error,
              size: widget.width,
              color: Colors.red,
            );
          case DownloadStatus.notDownloaded:
          default:
            return Icon(
              CustomIcons.download,
              size: widget.width,
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
