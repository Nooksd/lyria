import 'package:flutter/material.dart';

class MusicTile extends StatelessWidget {
  final String image;
  final bool isRound;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const MusicTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.image,
    required this.isRound,
    required this.onTap,
    required this.trailing,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(isRound ? 100 : 10),
        child: Container(
          width: 55,
          height: 55,
          decoration: BoxDecoration(
            color: isRound ? Theme.of(context).colorScheme.primary : null,
            image: DecorationImage(
              image: NetworkImage(image),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      trailing: trailing,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
