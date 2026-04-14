import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/modules/common/music_tile.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_cubit.dart';
import 'package:lyria/app/core/services/http/my_http_client.dart';

class GenrePage extends StatefulWidget {
  final String genre;
  const GenrePage({super.key, required this.genre});

  @override
  State<GenrePage> createState() => _GenrePageState();
}

class _GenrePageState extends State<GenrePage> {
  final MusicCubit musicCubit = getIt<MusicCubit>();
  final MyHttpClient http = getIt<MyHttpClient>();

  List<Map<String, dynamic>> artists = [];
  List<Music> musics = [];
  List<Map<String, dynamic>> albums = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGenre();
  }

  Future<void> _loadGenre() async {
    try {
      final response = await http.get('/genre/${widget.genre}');
      if (response['status'] == 200) {
        final data = response['data'];
        setState(() {
          artists = (data['artists'] as List? ?? [])
              .map((a) => Map<String, dynamic>.from(a))
              .toList();
          musics = (data['musics'] as List? ?? [])
              .map((m) => Music.fromJson(m))
              .toList();
          albums = (data['albums'] as List? ?? [])
              .map((a) => Map<String, dynamic>.from(a))
              .toList();
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/auth/ui/explorer');
            }
          },
        ),
        title: Text(
          widget.genre,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (artists.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      "Artistas",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 130,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: artists.length,
                        itemBuilder: (context, index) {
                          final artist = artists[index];
                          final avatarUrl = artist['avatarUrl'] ?? '';
                          final name = artist['name'] ?? '';

                          return GestureDetector(
                            onTap: () {
                              context.push('/auth/ui/artist',
                                  extra: artist['_id']);
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(right: 20),
                              child: Column(
                                children: [
                                  ClipOval(
                                    child: SizedBox(
                                      width: 90,
                                      height: 90,
                                      child: avatarUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: avatarUrl,
                                              fit: BoxFit.cover,
                                              placeholder: (_, __) => Container(
                                                color: Theme.of(context).colorScheme.primary,
                                                child: const Icon(Icons.person, color: Colors.white54, size: 40),
                                              ),
                                              errorWidget: (_, __, ___) => Container(
                                                color: Theme.of(context).colorScheme.primary,
                                                child: const Icon(Icons.person, color: Colors.white54, size: 40),
                                              ),
                                            )
                                          : Container(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              child: const Icon(Icons.person,
                                                  color: Colors.white54,
                                                  size: 40),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: 90,
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  if (albums.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      "Álbuns",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: albums.length,
                        itemBuilder: (context, index) {
                          final album = albums[index];
                          final coverUrl = album['albumCoverUrl'] ?? '';
                          final albumName = album['name'] ?? '';

                          return GestureDetector(
                            onTap: () {
                              context.push('/auth/ui/album',
                                  extra: album['_id']);
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox(
                                      width: 150,
                                      height: 150,
                                      child: coverUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: coverUrl,
                                              fit: BoxFit.cover,
                                              placeholder: (_, __) => Container(
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                              errorWidget: (_, __, ___) => Container(
                                                color: Theme.of(context).colorScheme.primary,
                                                child: const Icon(Icons.album, color: Colors.white54, size: 40),
                                              ),
                                            )
                                          : Container(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: 150,
                                    child: Text(
                                      albumName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  if (musics.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      "Músicas",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(
                      musics.length,
                      (index) => MusicTile(
                        title: musics[index].name,
                        subtitle: musics[index].artistName,
                        image: musics[index].coverUrl,
                        isRound: false,
                        onTap: () =>
                            musicCubit.setQueue(musics, index, null),
                        onLongPress: () {},
                        trailing: null,
                      ),
                    ),
                  ],
                  const SizedBox(height: 120),
                ],
              ),
            ),
    );
  }
}
