import 'package:flutter/material.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';

class CreateMusicJamTile extends StatelessWidget {
  const CreateMusicJamTile({super.key});

  void _onCreate() {}
  void _onJoin() {}

  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      useRootNavigator: true,
      builder: (context) => Container(
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
                  ListTile(
                    leading: const Icon(CustomIcons.jam),
                    title: const Text('Criar MusicJam'),
                    onTap: () {
                      Navigator.pop(context);
                      _onCreate();
                    },
                  ),
                  ListTile(
                    leading: const Icon(CustomIcons.connect),
                    title: const Text('Entrar em MusicJam'),
                    onTap: () {
                      Navigator.pop(context);
                      _onJoin();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

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
                onPressed: () => _showBottomSheet(context),
                child: Icon(
                  CustomIcons.plus_thick,
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
