import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:lyria/app/core/custom/splash.dart';
import 'package:lyria/app/modules/album/presentation/pages/album_page.dart';
import 'package:lyria/app/modules/library/presentation/pages/add_artist.dart';
import 'package:lyria/app/modules/artist/presentation/pages/artist_page.dart';
import 'package:lyria/app/modules/auth/presentation/cubits/auth_cubit.dart';
import 'package:lyria/app/modules/auth/presentation/pages/decide_page.dart';
import 'package:lyria/app/modules/explorer/presentation/cubits/search_cubit.dart';
import 'package:lyria/app/modules/explorer/presentation/pages/explorer_page.dart';
import 'package:lyria/app/modules/home/presentation/pages/home_page.dart';
import 'package:lyria/app/modules/library/domain/entities/playlist.dart';
import 'package:lyria/app/modules/library/presentation/cubits/playlist_cubit.dart';
import 'package:lyria/app/modules/library/presentation/pages/add_playlist.dart';
import 'package:lyria/app/modules/library/presentation/pages/library_page.dart';
import 'package:lyria/app/modules/library/presentation/pages/playlist_page.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_cubit.dart';
import 'package:lyria/app/modules/library/presentation/pages/add_music.dart';
import 'package:lyria/app/modules/music/presentation/pages/music_page.dart';
import 'package:lyria/app/modules/ui/includes/navigator_page.dart';
import 'package:flutter/material.dart';

final GetIt getIt = GetIt.instance;

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/auth',
    routes: [
      GoRoute(
        path: '/auth',
        pageBuilder: (context, state) => NoTransitionPage(
          child: BlocProvider.value(
            value: getIt<AuthCubit>()..checkAuth(),
            child: const SplashScreen(),
          ),
        ),
      ),
      GoRoute(
        path: '/auth/decide',
        pageBuilder: (context, state) => NoTransitionPage(
          child: BlocProvider.value(
            value: getIt<AuthCubit>(),
            child: const DecidePage(),
          ),
        ),
      ),
      GoRoute(
        path: '/auth/music',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: BlocProvider.value(
            value: getIt<MusicCubit>(),
            child: const MusicPage(),
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final overlayAnimation = CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.4),
            );

            final contentAnimation = CurvedAnimation(
              parent: animation,
              curve: const Interval(0.4, 1.0),
            );

            return Stack(
              children: [
                FadeTransition(
                  opacity: overlayAnimation,
                  child: Container(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.4),
                  ),
                ),
                SlideTransition(
                  position: Tween(
                    begin: const Offset(0.0, 1.0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(
                    opacity: contentAnimation,
                    child: child,
                  ),
                ),
              ],
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
          reverseTransitionDuration: const Duration(milliseconds: 500),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => NavigatorPage(child: child),
        routes: [
          GoRoute(
            path: '/auth/ui/home',
            pageBuilder: (context, state) => NoTransitionPage(
              child: BlocProvider(
                create: (context) => getIt<AuthCubit>(),
                child: HomePage(),
              ),
            ),
          ),
          GoRoute(
            path: '/auth/ui/explorer',
            pageBuilder: (context, state) => NoTransitionPage(
              child: BlocProvider.value(
                value: getIt<SearchCubit>(),
                child: ExplorerPage(),
              ),
            ),
          ),
          GoRoute(
            path: '/auth/ui/library',
            pageBuilder: (context, state) => NoTransitionPage(
              child: BlocProvider.value(
                value: getIt<PlaylistCubit>(),
                child: LibraryPage(),
              ),
            ),
          ),
          GoRoute(
            path: '/auth/ui/album',
            pageBuilder: (context, state) => NoTransitionPage(
              child: AlbumPage(),
            ),
          ),
          GoRoute(
            path: '/auth/ui/artist',
            pageBuilder: (context, state) => NoTransitionPage(
              child: ArtistPage(),
            ),
          ),
          GoRoute(
            path: '/auth/ui/playlist',
            pageBuilder: (context, state) => NoTransitionPage(
              child: PlaylistPage(playlist: state.extra as Playlist),
            ),
          ),
          GoRoute(
            path: '/auth/ui/addPlaylist',
            pageBuilder: (context, state) => NoTransitionPage(
              child: AddPlaylist(),
            ),
          ),
          GoRoute(
            path: '/auth/ui/addArtist',
            pageBuilder: (context, state) => NoTransitionPage(
              child: AddArtist(),
            ),
          ),
          GoRoute(
            path: '/auth/ui/addMusic',
            pageBuilder: (context, state) => NoTransitionPage(
              child: AddMusic(),
            ),
          ),
        ],
      ),
    ],
  );
}
