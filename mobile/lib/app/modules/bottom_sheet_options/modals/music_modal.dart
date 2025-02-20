import 'package:flutter/material.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/bottom_sheet_options/page/custom_bottom_modals.dart';
import 'package:lyria/app/modules/common/music_tile.dart';

class MusicModal extends CustomModal {
  MusicModal(super.search);

  Future<void> _addToQueue() async {
    if (search.music != null) {
      await cubit.addToQueue(search.music!);
    }
  }

  Future<void> _onPlay() async {
    if (search.music != null) {
      await cubit.setQueue([search.music!], 0, null);
    }
  }

  Future<void> _onShare() async {}
  Future<void> _addToPlaylist() async {}

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
                  leading: const Icon(CustomIcons.play),
                  title: const Text('Tocar música'),
                  onTap: () {
                    Navigator.pop(context);
                    _onPlay();
                  },
                ),
                ListTile(
                  leading: const Icon(CustomIcons.plus),
                  title: const Text('Adicionar a fila'),
                  onTap: () {
                    Navigator.pop(context);
                    _addToQueue();
                  },
                ),
                ListTile(
                  leading: const Icon(CustomIcons.add_to_playlist),
                  title: const Text('Adicionar à playlist'),
                  onTap: () {
                    Navigator.pop(context);
                    _addToPlaylist();
                  },
                ),
                ListTile(
                  leading: const Icon(CustomIcons.share),
                  title: const Text('Compartilhar'),
                  onTap: () {
                    Navigator.pop(context);
                    _onShare();
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