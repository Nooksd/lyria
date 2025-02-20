import 'package:flutter/material.dart';
import 'package:lyria/app/modules/explorer/domain/entities/search.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_cubit.dart';
import 'package:get_it/get_it.dart';

abstract class CustomModal {
  final Search search;
  final MusicCubit cubit = GetIt.I<MusicCubit>();

  CustomModal(this.search);

  void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      useRootNavigator: true,
      builder: (context) => buildContent(context),
    );
  }

  Widget buildContent(BuildContext context);
}

