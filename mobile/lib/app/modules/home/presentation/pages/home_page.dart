import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/assets/custom_container.dart';
import 'package:lyria/app/modules/home/presentation/pages/create_music_jam_tile.dart';
import 'package:lyria/app/modules/home/presentation/pages/playing_music_tile.dart';
import 'package:lyria/app/modules/home/presentation/pages/queue_tile.dart';
import 'package:lyria/app/modules/assets/seek_tile.dart';
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
  bool isRotating = true;

  final MusicCubit cubit = getIt<MusicCubit>();
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _initVolumeControl();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );
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

  void _handleMusicStateChange(MusicState state) {
    if (state is MusicPlaying && state.isPlaying) {
      _rotationController.repeat();
    } else {
      _rotationController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return BlocBuilder<MusicCubit, MusicState>(
      bloc: cubit,
      builder: (context, state) {
        _handleMusicStateChange(state);

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
                                  child: CreateMusicJamTile(),
                                ),
                                if (state is MusicPlaying)
                                  SizedBox(width: screenWidth * 0.05),
                                if (state is MusicPlaying)
                                  GestureDetector(
                                    onTap: () => context.push('/auth/music'),
                                    child: CustomContainer(
                                      width: screenWidth * 0.35,
                                      height: 200,
                                      child: PlayingMusicTile(
                                        state: state,
                                        rotationController: _rotationController,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (state is MusicPlaying)
                              CustomContainer(
                                width: screenWidth * 0.75,
                                height: 70,
                                child: SeekTile(),
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                            .withValues(
                                                alpha: volume >= (index + 1)
                                                    ? 1
                                                    : 0.4),
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
