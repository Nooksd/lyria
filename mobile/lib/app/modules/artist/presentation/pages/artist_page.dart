import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/modules/common/music_tile.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_cubit.dart';
import 'package:lyria/app/core/services/http/my_http_client.dart';

class ArtistPage extends StatefulWidget {
  final String artistId;
  const ArtistPage({super.key, required this.artistId});

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  final MusicCubit musicCubit = getIt<MusicCubit>();
  final MyHttpClient http = getIt<MyHttpClient>();

  Map<String, dynamic>? artist;
  List<Music> topMusics = [];
  List<Map<String, dynamic>> albums = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArtist();
  }

  Future<void> _loadArtist() async {
    try {
      final response = await http.get('/artist/${widget.artistId}');
      if (response['status'] == 200) {
        final data = response['data'];
        setState(() {
          artist = data['artist'];
          topMusics = (data['musics'] as List? ?? [])
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
    if (isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    if (artist == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: Text("Artista não encontrado")),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final avatarUrl = artist!['avatarUrl'] ?? '';
    final name = artist!['name'] ?? '';
    final bio = artist!['bio'] ?? '';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (avatarUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: avatarUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: Theme.of(context).colorScheme.primaryContainer,
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: const Icon(Icons.person, size: 80, color: Colors.white54),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.8),
                          Theme.of(context).colorScheme.primaryContainer,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      bio,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                  if (topMusics.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      "Músicas populares",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
          if (topMusics.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final music = topMusics[index];
                  return Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                    child: MusicTile(
                      title: music.name,
                      subtitle: music.albumName,
                      image: music.coverUrl,
                      isRound: false,
                      onTap: () =>
                          musicCubit.setQueue(topMusics, index, null),
                      onLongPress: () {},
                      trailing: null,
                    ),
                  );
                },
                childCount:
                    topMusics.length > 5 ? 5 : topMusics.length,
              ),
            ),
          if (albums.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
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
                ),
              ),
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 120),
          ),
        ],
      ),
    );
  }
}
