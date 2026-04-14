import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/auth/presentation/cubits/auth_cubit.dart';
import 'package:lyria/app/modules/library/presentation/includes/playlists_include.dart';
import 'package:lyria/app/modules/ui/includes/custom_appbar.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  void _goToDownloads(BuildContext context) {
    context.push('/auth/ui/downloads');
  }

  void _goToFavorites(BuildContext context) {
    context.push('/auth/ui/favorites');
  }

  void _goToAddPlaylist(BuildContext context) {
    context.push("/auth/ui/addPlaylist");
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final user = getIt<AuthCubit>().currentUser;

    return Scaffold(
      appBar: CustomAppBar(),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (user != null)
                  GestureDetector(
                    onTap: () => context.push('/auth/ui/profile'),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        child: user.avatarUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: user.avatarUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: Theme.of(context).colorScheme.primary,
                                  child: const Icon(Icons.person, color: Colors.white54, size: 24),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: Theme.of(context).colorScheme.primary,
                                  child: const Icon(Icons.person, color: Colors.white54, size: 24),
                                ),
                              )
                            : Icon(Icons.person, color: Colors.white54, size: 24),
                      ),
                    ),
                  ),
                SizedBox(
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => _goToDownloads(context),
                        icon: Icon(
                          CustomIcons.download,
                          size: 25,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _goToFavorites(context),
                        icon: Icon(
                          CustomIcons.heart_outline,
                          size: 25,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _goToAddPlaylist(context),
                        icon: Icon(
                          CustomIcons.plus,
                          size: 25,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Expanded(
              child: PlaylistsInclude(),
            ),
          ],
        ),
      ),
    );
  }
}
