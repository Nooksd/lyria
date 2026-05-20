import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/common/music_tile.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_cubit.dart';

void showMusicOptionsSheet(
  BuildContext context,
  Music music, {
  List<Widget> Function(BuildContext sheetContext)? extraActionsBuilder,
}) {
  final cubit = GetIt.I<MusicCubit>();

  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
    useRootNavigator: true,
    builder: (sheetContext) => Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 50),
            child: Container(
              width: double.infinity,
              height: 2,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          IgnorePointer(
            child: MusicTile(
              title: music.name,
              subtitle: music.artistName,
              image: music.coverUrl,
              isRound: false,
              onTap: () {},
              trailing: null,
              onLongPress: () {},
            ),
          ),
          const SizedBox(height: 20),
          const Text('Opções'),
          ListTile(
            leading: const Icon(CustomIcons.play),
            title: const Text('Tocar música'),
            onTap: () {
              Navigator.pop(sheetContext);
              cubit.setQueue([music], 0, null);
            },
          ),
          ListTile(
            leading: const Icon(CustomIcons.plus),
            title: const Text('Adicionar a fila'),
            onTap: () {
              Navigator.pop(sheetContext);
              cubit.addToQueue(music);
            },
          ),
          ListTile(
            leading: const Icon(CustomIcons.add_to_playlist),
            title: const Text('Adicionar à playlist'),
            onTap: () {
              Navigator.pop(sheetContext);
            },
          ),
          ListTile(
            leading: const Icon(CustomIcons.share),
            title: const Text('Compartilhar'),
            onTap: () {
              Navigator.pop(sheetContext);
            },
          ),
          if (extraActionsBuilder != null) ...extraActionsBuilder(sheetContext),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}
