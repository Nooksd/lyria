import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/auth/domain/entities/app_user.dart';
import 'package:lyria/app/modules/auth/presentation/cubits/auth_cubit.dart';
import 'package:lyria/app/modules/library/presentation/includes/playlists_include.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_cubit.dart';
import 'package:lyria/app/modules/ui/includes/custom_appbar.dart';

class LibraryPage extends StatelessWidget {
  final AppUser? user = getIt<AuthCubit>().currentUser;
  final AuthCubit authCubit = getIt<AuthCubit>();
  final MusicCubit musicCubit = getIt<MusicCubit>();

  LibraryPage({super.key});

  void _temp(BuildContext context) {
    authCubit.logout(context);
  }

  void _goToDownloads(BuildContext context) {}
  void _goToFavorites(BuildContext context) {}
  void _goToAddPlaylist(BuildContext context) {
    context.push("/auth/ui/addPlaylist");
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

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
                    onTap: () => _temp(context),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          image: DecorationImage(
                            image: NetworkImage(user!.avatarUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
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
