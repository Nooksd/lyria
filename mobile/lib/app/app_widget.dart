import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:lyria/app/core/custom/splash.dart';
import 'package:lyria/app/core/themes/light_theme.dart';
import 'package:lyria/app/modules/auth/presentation/cubits/auth_cubit.dart';
import 'package:lyria/app/modules/auth/presentation/pages/decide_page.dart';
import 'package:lyria/app/service_locator.dart';
import 'package:lyria/main.dart';

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

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      title: 'Connect',
      theme: lightTheme,
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: '/auth',
      routes: {
        '/auth': (context) => BlocProvider.value(
              value: getIt<AuthCubit>()..checkAuth(),
              child: const SplashScreen(),
            ),
        '/auth/decide': (context) => BlocProvider.value(
              value: getIt<AuthCubit>(),
              child: const DecidePage(),
            ),
      },
    );
  }
}
