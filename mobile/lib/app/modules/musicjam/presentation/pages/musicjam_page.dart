import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/config/api_config.dart';
import 'package:lyria/app/modules/musicjam/presentation/cubits/jam_cubit.dart';

class MusicJamPage extends StatelessWidget {
  MusicJamPage({super.key});

  final JamCubit jamCubit = getIt<JamCubit>();

  void _copyCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code.toUpperCase()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Codigo copiado!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _leaveJam(BuildContext context) async {
    await jamCubit.leaveJam();
    if (context.mounted) context.go('/auth/ui/home');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return BlocBuilder<JamCubit, JamState>(
      bloc: jamCubit,
      builder: (context, jamState) {
        final simpleId = jamState.simpleId ?? '';
        final participants = jamState.participants;

        if (!jamState.isInJam) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/auth/ui/home');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.mounted) context.go('/auth/ui/home');
              },
            ),
            title: const Text(
              "Music Jam",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              GestureDetector(
                onTap: () => _copyCode(context, simpleId),
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.copy, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        simpleId.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                const Text(
                  "Participantes",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: participants.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhum participante',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.builder(
                          itemCount: participants.length,
                          itemBuilder: (context, index) {
                            final p = participants[index];
                            final avatarUrl =
                                ApiConfig.fixImageUrl(p['avatarUrl'] as String?);
                            final name = (p['name'] as String?) ?? '';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  ClipOval(
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      color: Colors.grey[800],
                                      child: avatarUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: avatarUrl,
                                              fit: BoxFit.cover,
                                              fadeInDuration: Duration.zero,
                                              fadeOutDuration: Duration.zero,
                                              placeholder: (_, __) =>
                                                  const Icon(
                                                    Icons.person,
                                                    color: Colors.white54,
                                                    size: 24),
                                              errorWidget:
                                                  (_, __, ___) =>
                                                      const Icon(
                                                    Icons.person,
                                                    color: Colors.white54,
                                                    size: 24),
                                            )
                                          : const Icon(
                                              Icons.person,
                                              color: Colors.white54,
                                              size: 24),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (index == 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        'Host',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _leaveJam(context),
                        icon: const Icon(Icons.exit_to_app),
                        label: const Text(
                          'Sair da Jam',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
