// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/assets/custom_container.dart';
import 'package:lyria/app/modules/home/presentation/pages/queue_tile.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_cubit.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_states.dart';
import 'package:lyria/app/modules/ui/includes/custom_appbar.dart';
import 'package:volume_controller/volume_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  int volume = 0;

  final MusicCubit cubit = getIt<MusicCubit>();
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _initVolumeControl();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    VolumeController.instance.showSystemUI = true;
    VolumeController.instance.removeListener();
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _initVolumeControl() async {
    VolumeController.instance.showSystemUI = false;
    await _getVolume();
    VolumeController.instance.addListener((newVolume) {
      setState(() {
        volume = (newVolume * 10).round();
      });
    });
  }

  Future<void> _getVolume() async {
    double currentVolume = await VolumeController.instance.getVolume();
    setState(() {
      volume = (currentVolume * 10).round();
    });
  }

  Future<void> _setVolume(int newVolume) async {
    if (newVolume >= 0 && newVolume <= 10) {
      double volumeToSet = newVolume / 10;
      await VolumeController.instance.setVolume(volumeToSet);
      setState(() {
        volume = newVolume;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return BlocBuilder<MusicCubit, MusicState>(
      bloc: cubit,
      builder: (context, state) {
        return Scaffold(
          appBar: CustomAppBar(),
          body: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 45),
              if (state is MusicPlaying) QueueTile(),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03),
                child: Text(
                  'Painel de controle',
                  style: TextStyle(
                    fontSize: 20,
                  ),
                ),
              ),
              SizedBox(height: 20),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03),
                child: SizedBox(
                  height: 300,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomContainer(
                                  width: state is MusicPlaying
                                      ? screenWidth * 0.35
                                      : screenWidth * 0.7,
                                  height: state is MusicPlaying ? 200 : 300,
                                  child: Stack(
                                    children: [
                                      Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                                shape: CircleBorder(),
                                                padding: EdgeInsets.all(0),
                                                minimumSize: Size(50, 50),
                                              ),
                                              onPressed: () {},
                                              child: Icon(
                                                CustomIcons.plus,
                                                size: 30,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onPrimary,
                                              ),
                                            ),
                                            SizedBox(height: 10),
                                            Text(
                                              'Criar MusicJam',
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Positioned(
                                        right: 25,
                                        bottom: 25,
                                        child: Icon(
                                          CustomIcons.connect,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (state is MusicPlaying)
                                  SizedBox(width: screenWidth * 0.05),
                                if (state is MusicPlaying)
                                  CustomContainer(
                                    width: screenWidth * 0.35,
                                    height: 200,
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          top: 0,
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Center(
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(100),
                                              child: RotationTransition(
                                                turns: _rotationController,
                                                child: Container(
                                                  width: screenWidth * 0.25,
                                                  height: screenWidth * 0.25,
                                                  decoration: BoxDecoration(
                                                    image: DecorationImage(
                                                      image: NetworkImage(
                                                        state.currentMusic
                                                            .coverUrl,
                                                      ),
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          left: 0,
                                          right: 0,
                                          top: 0,
                                          bottom: 0,
                                          child: Center(
                                            child: Container(
                                              width: screenWidth * 0.25,
                                              height: screenWidth * 0.25,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(100),
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primaryContainer
                                                    .withOpacity(0.8),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          top: 0,
                                          left: 0,
                                          right: 0,
                                          child: Center(
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                              ),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    state.currentMusic.name,
                                                    textAlign: TextAlign.center,
                                                    maxLines: 3,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 16,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurface,
                                                    ),
                                                  ),
                                                  Text(
                                                    state.currentMusic.artistName,
                                                    textAlign: TextAlign.center,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurface,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            if (state is MusicPlaying)
                              CustomContainer(
                                width: screenWidth * 0.75,
                                height: 70,
                                child: Center(
                                  child: Text('Waveform'),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 300,
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () => _setVolume(volume + 1),
                              child: CustomContainer(
                                width: screenWidth * 0.13,
                                height: 25,
                                child: Icon(CustomIcons.plus, size: 13),
                              ),
                            ),
                            SizedBox(height: 20),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(
                                  10,
                                  (index) {
                                    return Container(
                                      width: screenWidth * 0.13,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(
                                                volume >= (index + 1) ? 1 : 0.4),
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                    );
                                  },
                                ).reversed.toList(),
                              ),
                            ),
                            SizedBox(height: 20),
                            GestureDetector(
                              onTap: () => _setVolume(volume - 1),
                              child: CustomContainer(
                                width: screenWidth * 0.13,
                                height: 25,
                                child: Icon(CustomIcons.minus, size: 4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
