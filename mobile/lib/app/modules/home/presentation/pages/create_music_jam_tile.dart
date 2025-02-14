import 'package:flutter/material.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';

class CreateMusicJamTile extends StatelessWidget {
  const CreateMusicJamTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: CircleBorder(),
                  padding: EdgeInsets.all(0),
                  minimumSize: Size(50, 50),
                ),
                onPressed: () {},
                child: Icon(
                  CustomIcons.plus,
                  size: 30,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Criar MusicJam',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 25,
          bottom: 25,
          child: Icon(CustomIcons.connect),
        ),
      ],
    );
  }
}