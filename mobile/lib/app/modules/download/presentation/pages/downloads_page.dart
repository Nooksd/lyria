import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/common/music_tile.dart';
import 'package:lyria/app/modules/download/data/api_download_repo.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_cubit.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  final MusicCubit musicCubit = getIt<MusicCubit>();
  final ApiDownloadRepo downloadRepo = getIt<ApiDownloadRepo>();

  List<Music> downloads = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDownloads();
  }

  Future<void> _loadDownloads() async {
    try {
      final musics = await downloadRepo.getDownloadedMusics();
      if (mounted) {
        setState(() {
          downloads = musics;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _deleteDownload(int index) async {
    final music = downloads[index];
    await downloadRepo.deleteMusic(music.id);
    setState(() {
      downloads.removeAt(index);
    });
  }

  void _playAll() {
    if (downloads.isNotEmpty) {
      musicCubit.setQueue(downloads, 0, null);
    }
  }

  void _shuffle() {
    if (downloads.isNotEmpty) {
      final shuffled = List<Music>.from(downloads)..shuffle();
      musicCubit.setQueue(shuffled, 0, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text("Downloads"),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primary))
          : downloads.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CustomIcons.download,
                        size: 60,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Nenhuma música baixada",
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: Theme.of(context).colorScheme.onPrimary,
                  backgroundColor: primary,
                  onRefresh: _loadDownloads,
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          '${downloads.length} música${downloads.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _playAll,
                                icon: Icon(CustomIcons.play, size: 16),
                                label: const Text("Tocar"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor:
                                      Theme.of(context).colorScheme.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _shuffle,
                                icon: Icon(CustomIcons.shuffle, size: 16),
                                label: const Text("Aleatório"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: primary,
                                  side: BorderSide(color: primary),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.builder(
                            itemCount: downloads.length,
                            itemBuilder: (context, index) {
                              final music = downloads[index];
                              return MusicTile(
                                title: music.name,
                                subtitle: music.artistName,
                                image: music.coverUrl,
                                isRound: false,
                                onTap: () => musicCubit.setQueue(
                                    downloads, index, null),
                                onLongPress: () {},
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _deleteDownload(index),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
