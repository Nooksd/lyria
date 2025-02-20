import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/common/custom_container.dart';
import 'package:lyria/app/modules/library/domain/entities/playlist.dart';
import 'package:lyria/app/modules/library/presentation/cubits/playlist_cubit.dart';
import 'package:lyria/app/modules/library/presentation/cubits/playlist_states.dart';

class PlaylistsInclude extends StatefulWidget {
  const PlaylistsInclude({super.key});

  @override
  State<PlaylistsInclude> createState() => _PlaylistsIncludeState();
}

class _PlaylistsIncludeState extends State<PlaylistsInclude> {
  final PlaylistCubit playlistCubit = getIt<PlaylistCubit>();

  @override
  void initState() {
    super.initState();
    playlistCubit.getPlaylists();
  }

  void _openPlaylist(Playlist playlist) {
    context.push('/auth/ui/playlist', extra: playlist);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = 3;
    final spacing = screenWidth * 0.05;
    final itemWidth =
        (screenWidth - (crossAxisCount + 2) * spacing) / crossAxisCount;

    return BlocBuilder<PlaylistCubit, PlaylistState>(
      bloc: playlistCubit,
      builder: (context, state) {
        if (state is PlaylistLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is PlaylistLoaded) {
          List<Playlist> playlists = state.playlists;

          return RefreshIndicator(
            color: Theme.of(context).colorScheme.onPrimary,
            backgroundColor: Theme.of(context).colorScheme.primary,
            onRefresh: () async {
              await playlistCubit.getPlaylists();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Biblioteca',
                    style: TextStyle(fontSize: 25),
                  ),
                  const SizedBox(height: 20),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: playlists.length + 2,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: spacing,
                      crossAxisSpacing: spacing,
                      childAspectRatio: 0.7,
                    ),
                    itemBuilder: (context, index) {
                      if (index < playlists.length) {
                        final playlist = playlists[index];
                        return SizedBox(
                          width: itemWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => _openPlaylist(playlist),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: itemWidth,
                                    height: itemWidth,
                                    decoration: BoxDecoration(
                                      image: DecorationImage(
                                        image: NetworkImage(playlist.imageUrl),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              SizedBox(
                                width: itemWidth,
                                child: Text(
                                  playlist.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              Text(
                                '${playlist.musics.length} Músicas',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        );
                      } else if (index == playlists.length) {
                        return GestureDetector(
                          onTap: () {},
                          child: Column(
                            children: [
                              CustomContainer(
                                width: itemWidth,
                                height: itemWidth,
                                borderRadius: 100,
                                child: Center(
                                  child: Icon(
                                    CustomIcons.plus_thick,
                                    size: 30,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              SizedBox(
                                width: itemWidth,
                                child: Text(
                                  "Adicionar Artista",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
                        // Botão "Adicionar Playlist"
                        return GestureDetector(
                          onTap: () {},
                          child: Column(
                            children: [
                              CustomContainer(
                                width: itemWidth,
                                height: itemWidth,
                                borderRadius: 10,
                                child: Center(
                                  child: Icon(
                                    CustomIcons.plus_thick,
                                    size: 30,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              SizedBox(
                                width: itemWidth,
                                child: Text(
                                  "Adicionar Playlist",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 300),
                ],
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
