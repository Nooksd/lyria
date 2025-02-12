import 'package:flutter/material.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/assets/music_tile.dart';
import 'package:lyria/app/modules/explorer/presentation/components/genre_tile.dart';
import 'package:lyria/app/modules/ui/includes/custom_appbar.dart';

class ExplorerPage extends StatefulWidget {
  const ExplorerPage({super.key});

  @override
  State<ExplorerPage> createState() => _ExplorerPageState();
}

class _ExplorerPageState extends State<ExplorerPage> {
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocus = FocusNode();
  bool isSearchFocused = false;
  List<Map<String, String>> recentSearches = [];

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
  void initState() {
    super.initState();
    searchFocus.addListener(() {
      setState(() {
        isSearchFocused = searchFocus.hasFocus;
      });
    });
    recentSearches = [
      {
        'name': 'Ela é Profissional',
        'image':
            'https://i1.sndcdn.com/avatars-WlCuo6NuEcfO1Gag-4KOIYw-t500x500.jpg',
        'subtitle': 'Música . GP DA ZL',
        'id': '1',
        'type': 'music',
      },
      {
        'name': 'GP DA ZL',
        'image':
            'https://i.scdn.co/image/ab6761610000e5eba0083f665d3c4a76119b20f2',
        'subtitle': 'Artista',
        'id': '2',
        'type': 'artist',
      },
    ];
  }

  @override
  void dispose() {
    searchController.dispose();
    searchFocus.dispose();
    super.dispose();
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
            SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: TextField(
                controller: searchController,
                focusNode: searchFocus,
                decoration: InputDecoration(
                  hintText: 'Pesquisar',
                  prefixIcon: Icon(
                    CustomIcons.search,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 60),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(50),
                    borderSide: BorderSide(
                      width: 1,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(50),
                    borderSide: BorderSide(
                      width: 1,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 40),
            Text(
              isSearchFocused ? 'Buscas recentes' : 'Gêneros',
              style: TextStyle(
                fontSize: 20,
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: !isSearchFocused
                  ? SingleChildScrollView(
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
                    )
                  : SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 100),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: List.generate(
                            recentSearches.length,
                            (index) => MusicTile(
                              title: recentSearches[index]['name']!,
                              subtitle: recentSearches[index]['subtitle']!,
                              image: recentSearches[index]['image']!,
                              isRound: recentSearches[index]['type'] == 'artist',
                              onTap: () {},
                              trailing: Icon(
                                CustomIcons.x,
                                size: 7,
                              ),
                            ),
                          ),
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
