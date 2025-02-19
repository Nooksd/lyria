import 'package:flutter/material.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/modules/auth/domain/entities/app_user.dart';
import 'package:lyria/app/modules/auth/presentation/cubits/auth_cubit.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_cubit.dart';
import 'package:lyria/app/modules/ui/includes/custom_appbar.dart';

class LibraryPage extends StatelessWidget {
  final AppUser? authCubit = getIt<AuthCubit>().currentUser;
  final MusicCubit musicCubit = getIt<MusicCubit>();

  LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: CustomAppBar(),
      body: Center(
        child: Text("LIBRARY"),
      ),
    );
  }
}
