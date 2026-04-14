import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class SplashAnimation extends StatelessWidget {
  const SplashAnimation({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox(
        width: MediaQuery.sizeOf(context).width,
        height: MediaQuery.sizeOf(context).height,
        child: Stack(
          children: [
            Center(
              child: SizedBox(
                width: 150,
                child: Lottie.asset(
                  'assets/animations/loading.json',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 50,
              child: SizedBox(
                width: 65,
                height: 35,
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
