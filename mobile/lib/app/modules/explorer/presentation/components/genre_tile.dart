import 'package:flutter/material.dart';
import 'package:lyria/app/modules/assets/custom_container.dart';

class GenreTile extends StatelessWidget {
  final double width;
  final String name;
  final String image;

  const GenreTile({
    super.key,
    required this.width,
    required this.name,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    double height = width * 1.13;
    return CustomContainer(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned(
            right: 0,
            bottom: 0,
            child: Image.asset(
              image,
              height: height * 0.9,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            top: 25,
            left: 20,
            child: Text(
              name,
              style: TextStyle(
                fontSize: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          )
        ],
      ),
    );
  }
}
