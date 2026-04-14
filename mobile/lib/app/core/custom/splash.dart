import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/custom/splash_animation.dart';
import 'package:lyria/app/core/themes/theme_cubit.dart';
import 'package:lyria/app/modules/auth/presentation/cubits/auth_cubit.dart';
import 'package:lyria/app/modules/auth/presentation/cubits/auth_states.dart';

class SplashScreen extends StatelessWidget {
  final ThemeCubit themeCubit = getIt<ThemeCubit>();

  SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is Authenticated) {
          context.go('/auth/ui/home');
        } else if (state is Unauthenticated) {
          themeCubit.updatePrimaryColor(Colors.white);
          context.go('/auth/decide');
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error)),
          );
        }
      },
      builder: (context, state) {
        return SplashAnimation();
      },
    );
  }
}
