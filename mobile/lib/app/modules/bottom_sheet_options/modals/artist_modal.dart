import 'package:flutter/material.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/bottom_sheet_options/page/custom_bottom_modals.dart';
import 'package:lyria/app/modules/common/music_tile.dart';

class ArtistModal extends CustomModal {
  ArtistModal(super.search);

  Future<void> _onOpen() async {}
  Future<void> _onShare() async {}

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
                    isRound: true,
                    onTap: () {},
                    trailing: null,
                    onLongPress: () {},
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Opções'),
                ListTile(
                  leading: const Icon(CustomIcons.profile),
                  title: const Text('Ver artista'),
                  onTap: () {
                    Navigator.pop(context);
                    _onOpen();
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