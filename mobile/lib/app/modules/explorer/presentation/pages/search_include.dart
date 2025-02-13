import 'package:flutter/material.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/assets/music_tile.dart';
import 'package:lyria/app/modules/explorer/domain/entities/search.dart';

class SearchInclude extends StatelessWidget {
  final List<Search> searches;
  final Function(int) onRemove;
  final bool isHistory;

  const SearchInclude({
    super.key,
    required this.searches,
    required this.onRemove,
    this.isHistory = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: searches.length,
      itemBuilder: (context, index) => MusicTile(
        title: searches[index].name,
        subtitle: searches[index].description,
        image: searches[index].imageUrl,
        isRound: searches[index].type == 'artist',
        onTap: () {},
        trailing: isHistory
            ? GestureDetector(
                onTap: () => onRemove(index),
                child: SizedBox(
                  width: 55,
                  height: 55,
                  child: Icon(CustomIcons.x, size: 10),
                ),
              )
            : Text(''),
      ),
    );
  }
}
