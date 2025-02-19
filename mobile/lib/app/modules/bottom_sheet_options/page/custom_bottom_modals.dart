import 'package:flutter/material.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/assets/music_tile.dart';
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

class MusicModal extends CustomModal {
  MusicModal(super.search);

  Future<void> _addToQueue() async {
    if (search.music != null) {
      await cubit.addToQueue(search.music!);
    }
  }

  Future<void> _onPlay() async {
    if (search.music != null) {
      await cubit.setQueue([search.music!], 0);
    }
  }

  @override
  Widget buildContent(BuildContext context) {
    return Container(
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
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                IgnorePointer(
                  child: MusicTile(
                    title: search.name,
                    subtitle: search.description,
                    image: search.imageUrl,
                    isRound: false,
                    onTap: () {},
                    trailing: null,
                    onLongPress: () {},
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Opções'),
                ListTile(
                  leading: const Icon(CustomIcons.plus),
                  title: const Text('Adicionar a fila'),
                  onTap: () {
                    Navigator.pop(context);
                    _addToQueue();
                  },
                ),
                ListTile(
                  leading: const Icon(CustomIcons.play),
                  title: const Text('Tocar música'),
                  onTap: () {
                    Navigator.pop(context);
                    _onPlay();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class ArtistModal extends CustomModal {
  ArtistModal(super.search);
  @override
  Widget buildContent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(CustomIcons.profile),
            title: Text('Ver artista'),
          ),
        ],
      ),
    );
  }
}
