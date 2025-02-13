import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/themes/light_theme.dart';
import 'package:lyria/app/modules/auth/presentation/cubits/auth_cubit.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_cubit.dart';

class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.light,
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ));

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(
          create: (context) => getIt<AuthCubit>(),
        ),
        BlocProvider<MusicCubit>(
          create: (context) => getIt<MusicCubit>(),
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'Lyria',
        theme: lightTheme,
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: AppRouter.router,
      ),
    );
  }
}
