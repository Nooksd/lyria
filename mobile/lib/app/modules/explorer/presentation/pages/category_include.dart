import 'package:flutter/material.dart';
import 'package:lyria/app/modules/explorer/presentation/components/genre_tile.dart';

class CategoryInclude extends StatelessWidget {
  CategoryInclude({super.key});

  final List<Map<String, String>> genres = [
    {
      'name1': 'Pop',
      'image1': 'assets/images/pop.png',
      'name2': 'Rock',
      'image2': 'assets/images/rock.png',
    },
    {
      'name1': 'Rap',
      'image1': 'assets/images/rap.png',
      'name2': 'Trap',
      'image2': 'assets/images/trap.png',
    },
    {
      'name1': 'Funk',
      'image1': 'assets/images/funk.png',
      'name2': 'Indie',
      'image2': 'assets/images/indie.png',
    }
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.only(bottom: 100),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            genres.length,
            (index) => Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GenreTile(
                      width: screenWidth * 0.425,
                      name: genres[index]['name1']!,
                      image: genres[index]['image1']!,
                    ),
                    GenreTile(
                      width: screenWidth * 0.425,
                      name: genres[index]['name2']!,
                      image: genres[index]['image2']!,
                    ),
                  ],
                ),
                SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
