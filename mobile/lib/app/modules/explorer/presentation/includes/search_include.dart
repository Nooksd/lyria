import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/common/music_tile.dart';
import 'package:lyria/app/modules/bottom_sheet_options/page/modal_factory.dart';
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

  Future<void> _onTap(BuildContext context, Search search) async {
    addToHistory(search);

    switch (search.type) {
      case 'music':
        if (search.music != null && search.music!.url != '') {
          await cubit.setQueue([search.music!], 0, null);
        }
        break;
      case 'artist':
        context.push('/auth/ui/artist', extra: search.id);
        break;
      case 'album':
        context.push('/auth/ui/album', extra: search.id);
        break;
      case 'playlist':
        break;
    }
  }

  void _showMoreOptions(BuildContext context, Search search) {
    final modal = createModal(search);
    modal.show(context);
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: searches.length,
      itemBuilder: (context, index) {
        final actualIndex =
            isHistory ? searches.length - 1 - index : index;
        final item = searches[actualIndex];
        return MusicTile(
          title: item.name,
          subtitle: item.description,
          image: item.imageUrl,
          isRound: item.type == 'artist',
          onTap: () {
            _onTap(context, item);
          },
          onLongPress: () => _showMoreOptions(context, item),
          trailing: isHistory
              ? GestureDetector(
                  onTap: () => onRemove(actualIndex),
                  child: SizedBox(
                    height: 55,
                    width: 20,
                    child: Icon(CustomIcons.x, size: 10),
                  ),
                )
              : Text(''),
        );
      },
    );
  }
}
