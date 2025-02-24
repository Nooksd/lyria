import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/ui/includes/custom_appbar.dart';

class AddArtist extends StatefulWidget {
  const AddArtist({super.key});

  @override
  State<AddArtist> createState() => _AddArtistState();
}

class _AddArtistState extends State<AddArtist> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 20,
              left: 20,
              child: SizedBox(
                width: 25,
                height: 30,
                child: IconButton(
                  onPressed: () => context.pop(),
                  icon: Icon(
                    CustomIcons.goback,
                    size: 25,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
