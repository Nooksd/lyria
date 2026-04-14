import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/connectivity/connectivity_cubit.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/musicjam/presentation/cubits/jam_cubit.dart';

class CreateMusicJamTile extends StatelessWidget {
  CreateMusicJamTile({super.key});

  final JamCubit jamCubit = getIt<JamCubit>();

  Future<void> _onCreate(BuildContext context) async {
    final simpleId = await jamCubit.createJam();
    if (simpleId != null && context.mounted) {
      context.go('/auth/ui/musicjam');
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao criar Music Jam')),
      );
    }
  }

  void _onJoin(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.primaryContainer,
        title: const Text(
          'Entrar em MusicJam',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Código da sala',
            hintStyle: const TextStyle(color: Colors.white54),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final code = controller.text.trim().toLowerCase();
              if (code.isEmpty) return;
              Navigator.pop(ctx);
              final joined = await jamCubit.joinJam(code);
              if (joined && context.mounted) {
                context.go('/auth/ui/musicjam');
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sala não encontrada')),
                );
              }
            },
            child: const Text('Entrar'),
          ),
        ],
      ),
    );
  }

  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      useRootNavigator: true,
      builder: (sheetCtx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50),
              child: Container(
                width: double.infinity,
                height: 2,
                decoration: BoxDecoration(
                  color: Theme.of(sheetCtx).colorScheme.primary,
                ),
              ),
            ),
            SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  ListTile(
                    leading: const Icon(CustomIcons.jam, color: Colors.white),
                    title: const Text('Criar MusicJam', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _onCreate(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(CustomIcons.connect, color: Colors.white),
                    title: const Text('Entrar em MusicJam', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _onJoin(context);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityCubit, bool>(
      bloc: getIt<ConnectivityCubit>(),
      builder: (context, isOnline) {
        return BlocBuilder<JamCubit, JamState>(
          bloc: jamCubit,
          builder: (context, jamState) {
            if (jamState.isInJam) {
              return _buildInJamView(context, jamState);
            }
            if (!isOnline) {
              return _buildOfflineView(context);
            }
            return _buildCreateView(context);
          },
        );
      },
    );
  }

  Widget _buildInJamView(BuildContext context, JamState jamState) {
    final participants = jamState.participants;
    const maxVisible = 4;
    final visibleCount =
        participants.length > maxVisible ? maxVisible : participants.length;
    final extraCount = participants.length - maxVisible;

    return GestureDetector(
      onTap: () {
        if (jamState.simpleId != null) {
          context.go('/auth/ui/musicjam');
        }
      },
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CustomIcons.jam,
              size: 28,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              'Music Jam',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (participants.isNotEmpty)
              SizedBox(
                height: 36,
                width: (visibleCount * 24.0) + 12 + (extraCount > 0 ? 28 : 0),
                child: Stack(
                  children: [
                    for (int i = 0; i < visibleCount; i++)
                      Positioned(
                        left: i * 24.0,
                        child: _buildAvatar(
                            context, participants[i], 34),
                      ),
                    if (extraCount > 0)
                      Positioned(
                        left: visibleCount * 24.0,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFF303030),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '+$extraCount',
                              style: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.onPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(
      BuildContext context, Map<String, dynamic> participant, double size) {
    final avatarUrl = (participant['avatarUrl'] as String?) ?? '';
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.primaryContainer,
          width: 2,
        ),
      ),
      child: ClipOval(
        child: avatarUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: avatarUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: primary,
                  child: const Icon(Icons.person,
                      color: Colors.white54, size: 16),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: primary,
                  child: const Icon(Icons.person,
                      color: Colors.white54, size: 16),
                ),
              )
            : Container(
                color: primary,
                child: const Icon(Icons.person,
                    color: Colors.white54, size: 16),
              ),
      ),
    );
  }

  Widget _buildOfflineView(BuildContext context) {
    return Opacity(
      opacity: 0.4,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off,
                size: 26,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'MusicJam Offline',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateView(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: CircleBorder(),
                  padding: EdgeInsets.all(0),
                  minimumSize: Size(50, 50),
                ),
                onPressed: () => _showBottomSheet(context),
                child: Icon(
                  CustomIcons.plus_thick,
                  size: 30,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Criar MusicJam',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 25,
          bottom: 25,
          child: Icon(CustomIcons.connect),
        ),
      ],
    );
  }
}
