import 'package:flutter/material.dart';

class MusicTile extends StatelessWidget {
  final String image;
  final bool isRound;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;

  const MusicTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.image,
    required this.isRound,
    required this.onTap,
    required this.trailing,
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
            image: DecorationImage(
              image: NetworkImage(image),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing,
    );
  }
}
