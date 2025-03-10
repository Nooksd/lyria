import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/common/custom_container.dart';
import 'package:lyria/app/modules/library/domain/entities/playlist.dart';
import 'package:lyria/app/modules/library/presentation/components/playlist_control.dart';
import 'package:lyria/app/modules/library/presentation/components/playlist_musics_builder.dart';
import 'package:lyria/app/modules/library/presentation/cubits/playlist_cubit.dart';

class PlaylistPage extends StatelessWidget {
  final Playlist playlist;
  final PlaylistCubit playlistCubit = getIt<PlaylistCubit>();

  PlaylistPage({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: CustomContainer(
        width: screenWidth,
        height: screenHeight,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(height: 30),
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Image.asset(
                      'assets/images/logo.png',
                      color: Theme.of(context).colorScheme.primary,
                      width: 50,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 30),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                child: SizedBox(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 25,
                        height: 30,
                        child: IconButton(
                          onPressed: () => context.pop(),
                          icon: Icon(
                            CustomIcons.goback,
                            size: 25,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: screenWidth * 0.6,
                          height: screenWidth * 0.6,
                          child: CachedNetworkImage(
                            imageUrl:
                                '${playlist.playlistCoverUrl}?v=${playlistCubit.cacheBuster}',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 30,
                        height: 30,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 15),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      style: TextStyle(
                        fontSize: 20,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '${playlist.musics.length} música${playlist.musics.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    SizedBox(height: 15),
                    PlaylistControl(
                      musics: playlist.musics,
                      playlistId: playlist.id,
                    ),
                    SizedBox(height: 15),
                    PlaylistMusicsBuilder(
                      musics: playlist.musics,
                      playlistId: playlist.id,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
