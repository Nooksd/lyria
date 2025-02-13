import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:lyria/app/core/custom/splash.dart';
import 'package:lyria/app/modules/auth/presentation/cubits/auth_cubit.dart';
import 'package:lyria/app/modules/auth/presentation/pages/decide_page.dart';
import 'package:lyria/app/modules/explorer/presentation/cubits/search_cubit.dart';
import 'package:lyria/app/modules/explorer/presentation/pages/explorer_page.dart';
import 'package:lyria/app/modules/home/presentation/pages/home_page.dart';
import 'package:lyria/app/modules/library/presentation/pages/library_page.dart';
import 'package:lyria/app/modules/ui/includes/navigator_page.dart';

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
            pageBuilder: (context, state) => const NoTransitionPage(
              child: LibraryPage(),
            ),
          ),
        ],
      ),
    ],
  );
}
