import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';
import 'package:lyria/app/modules/auth/presentation/cubits/auth_cubit.dart';
import 'package:lyria/app/modules/auth/presentation/cubits/auth_states.dart';
import 'package:lyria/app/modules/auth/presentation/pages/login_page.dart';
import 'package:lyria/main.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is Authenticated) {
          navigatorKey.currentState?.pushReplacementNamed('/navigator');
        } else if (state is Unauthenticated) {
          return const LoginPage();
        }

        return Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          body: SizedBox(
            width: MediaQuery.sizeOf(context).width,
            height: MediaQuery.sizeOf(context).height,
            // child: Lottie.asset('assets/InnovaSplash.json'),
          ),
        );
      },
      listener: (context, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error)),
          );
        }
      },
    );
  }
}
