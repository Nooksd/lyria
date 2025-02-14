import 'package:flutter/material.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/assets/music_tile.dart';
import 'package:lyria/app/modules/explorer/domain/entities/search.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_cubit.dart';

class SearchInclude extends StatelessWidget {
  final List<Search> searches;
  final Function(int) onRemove;
  final bool isHistory;
  final Function(Search search) addToHistory;

  final MusicCubit cubit = getIt<MusicCubit>();

  SearchInclude({
    super.key,
    required this.searches,
    required this.onRemove,
    this.isHistory = false,
    required this.addToHistory,
  });

  Future<void> _addToQueue(Search search) async {
    addToHistory(search);

    if (search.music != null && search.music!.url != '') {
      await cubit.addToQueue(search.music!);
    }
  }

  Future<void> _onTap(Search search) async {
    addToHistory(search);

    switch (search.type) {
      case 'music':
        if (search.music != null && search.music!.url != '') {
          await cubit.setQueue([search.music!], 0);
        }
        break;
      case 'artist':
        break;
      case 'album':
        break;
      case 'playlist':
        break;
    }
  }

  void _showMoreOptions(BuildContext context, Search search) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      useRootNavigator: true,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(CustomIcons.plus),
              title: Text('Adicionar a fila'),
              onTap: () {
                _addToQueue(search);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(CustomIcons.play),
              title: Text('Tocar música'),
              onTap: () {
                _onTap(search);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: searches.length,
      itemBuilder: (context, index) => MusicTile(
        title: searches[index].name,
        subtitle: searches[index].description,
        image: searches[index].imageUrl,
        isRound: searches[index].type == 'artist',
        onTap: () {
          _onTap(searches[index]);
        },
        onLongPress: () => _showMoreOptions(context, searches[index]),
        trailing: isHistory
            ? GestureDetector(
                onTap: () => onRemove(index),
                child: SizedBox(
                  height: 55,
                  width: 20,
                  child: Icon(CustomIcons.x, size: 10),
                ),
              )
            : Text(''),
      ),
    );
  }
}
