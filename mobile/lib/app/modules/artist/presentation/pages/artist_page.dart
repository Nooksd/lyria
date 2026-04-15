import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/config/api_config.dart';
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

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.transparent;
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('0xFF$clean'));
    }
    return Colors.transparent;
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
    final avatarUrl = ApiConfig.fixImageUrl(artist!['avatarUrl']);
    final bannerUrl = ApiConfig.fixImageUrl(artist!['bannerUrl']);
    final name = artist!['name'] ?? '';
    final bio = artist!['bio'] ?? '';
    final rawColor = artist!['color'] ?? '';
    final artistColor = _parseColor(rawColor);
    final hasColor = artistColor != Colors.transparent;
    final accentColor =
        hasColor ? artistColor : Theme.of(context).colorScheme.primary;
    final bgColor = Theme.of(context).colorScheme.primaryContainer;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner + avatar + back button (like profile page)
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Banner
                Container(
                  width: screenWidth,
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor,
                        accentColor.withValues(alpha: 0.6),
                        bgColor,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: bannerUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: bannerUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const SizedBox.shrink(),
                          errorWidget: (_, __, ___) =>
                              const SizedBox.shrink(),
                        )
                      : null,
                ),
                // Back button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 8,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                ),
                // Avatar
                Positioned(
                  bottom: -50,
                  left: screenWidth / 2 - 55,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: bgColor, width: 4),
                    ),
                    child: ClipOval(
                      child: Container(
                        width: 106,
                        height: 106,
                        color: Theme.of(context).colorScheme.primary,
                        child: avatarUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: avatarUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const Icon(
                                    Icons.person,
                                    size: 50,
                                    color: Colors.white54),
                                errorWidget: (_, __, ___) => const Icon(
                                    Icons.person,
                                    size: 50,
                                    color: Colors.white54),
                              )
                            : const Icon(Icons.person,
                                size: 50, color: Colors.white54),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 60),

            // Name
            Center(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Bio
            if (bio.isNotEmpty) ...[
              const SizedBox(height: 8),
              Center(
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
                  child: Text(
                    bio,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ],

            // Genres
            if (artist!['genres'] != null &&
                (artist!['genres'] as List).isNotEmpty) ...[
              const SizedBox(height: 12),
              Center(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children:
                      (artist!['genres'] as List).map<Widget>((genre) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        genre.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            // Top musics
            if (topMusics.isNotEmpty) ...[
              const SizedBox(height: 24),
              Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                child: const Text(
                  "Músicas populares",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...topMusics
                  .take(5)
                  .toList()
                  .asMap()
                  .entries
                  .map((entry) {
                final index = entry.key;
                final music = entry.value;
                return Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.05),
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
              }),
            ],

            // Albums
            if (albums.isNotEmpty) ...[
              const SizedBox(height: 32),
              Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                child: const Text(
                  "Álbuns",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.only(left: screenWidth * 0.05),
                  itemCount: albums.length,
                  itemBuilder: (context, index) {
                    final album = albums[index];
                    final coverUrl = ApiConfig.fixImageUrl(album['albumCoverUrl']);
                    final albumName = album['name'] ?? '';
                    final albumColorRaw = album['color'] ?? '';
                    final albumColor = _parseColor(albumColorRaw);
                    final hasAlbumColor =
                        albumColor != Colors.transparent;
                    final placeholderColor =
                        hasAlbumColor ? albumColor : accentColor;

                    return GestureDetector(
                      onTap: () {
                        context.push('/auth/ui/album',
                            extra: album['_id']);
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(12),
                              child: Container(
                                width: 150,
                                height: 150,
                                color: placeholderColor,
                                child: coverUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: coverUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) =>
                                            const SizedBox.shrink(),
                                        errorWidget:
                                            (_, __, ___) =>
                                                const Icon(
                                                    Icons.album,
                                                    color:
                                                        Colors.white54,
                                                    size: 40),
                                      )
                                    : const Icon(
                                        Icons.album,
                                        color:
                                            Colors.white54,
                                        size: 40),
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

            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }
}
