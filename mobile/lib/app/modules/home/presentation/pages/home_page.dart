import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/assets/custom_container.dart';
import 'package:lyria/app/modules/ui/includes/custom_appbar.dart';
import 'package:volume_controller/volume_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final getIt = GetIt.instance;
  int volume = 0;

  @override
  void initState() {
    super.initState();
    _getVolume();
    VolumeController.instance.showSystemUI = false;
  }

  @override
  void dispose() {
    VolumeController.instance.showSystemUI = true;
    super.dispose();
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

    return Scaffold(
      appBar: CustomAppBar(),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 45),
            Text(
              'Painel de controle',
              style: TextStyle(
                fontSize: 20,
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                CustomContainer(
                  width: 300,
                  height: 300,
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
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
                Spacer(),
                SizedBox(
                  height: 300,
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => _setVolume(volume + 1),
                        child: CustomContainer(
                          width: 50,
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
                                width: 50,
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
                          width: 50,
                          height: 25,
                          child: Icon(CustomIcons.minus, size: 4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
