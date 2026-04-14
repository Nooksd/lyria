import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/connectivity/connectivity_cubit.dart';
import 'package:lyria/app/core/services/connectivity/connectivity_service.dart';
import 'package:lyria/app/core/services/storege/my_local_storage.dart';
import 'package:lyria/app/modules/auth/presentation/cubits/auth_cubit.dart';
import 'package:lyria/app/modules/library/domain/entities/playlist.dart';
import 'package:lyria/app/modules/library/presentation/cubits/playlist_cubit.dart';
import 'package:lyria/app/modules/library/presentation/cubits/playlist_states.dart';
import 'package:lyria/app/core/services/http/my_http_client.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthCubit authCubit = getIt<AuthCubit>();
  final MyHttpClient http = getIt<MyHttpClient>();
  final PlaylistCubit playlistCubit = getIt<PlaylistCubit>();
  final ConnectivityService connectivity = getIt<ConnectivityService>();
  final MyLocalStorage storage = getIt<MyLocalStorage>();
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? profile;
  bool isLoading = true;
  String? _avatarCacheBuster;

  static const _profileCacheKey = 'cached_profile';

  @override
  void initState() {
    super.initState();
    _avatarCacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = authCubit.currentUser;
      if (user == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      // Load cached profile first
      final cachedRaw = await storage.get(_profileCacheKey);
      if (cachedRaw != null && mounted) {
        try {
          profile = jsonDecode(cachedRaw as String) as Map<String, dynamic>;
        } catch (_) {}
      }
      if (mounted) setState(() => isLoading = false);

      // Fetch from server if online
      if (connectivity.isOnline) {
        final profileRes = await http.get('/users/profile/${user.uid}');
        if (profileRes['status'] == 200 && mounted) {
          profile = profileRes['data'];
          await storage.set(_profileCacheKey, jsonEncode(profile));
          setState(() {});
        }
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;

    try {
      final file = File(picked.path);
      await http.multiPart('/image/avatar', body: {'avatar': file});
      setState(() {
        _avatarCacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao enviar foto')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final user = authCubit.currentUser;
    final primary = Theme.of(context).colorScheme.primary;

    if (isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: primary),
        ),
      );
    }

    final avatarUrl = user != null && user.avatarUrl.isNotEmpty
        ? '${user.avatarUrl}?v=$_avatarCacheBuster'
        : '';
    final avatarCacheKey =
        user != null && user.avatarUrl.isNotEmpty ? user.avatarUrl : null;

    return BlocBuilder<ConnectivityCubit, bool>(
      bloc: getIt<ConnectivityCubit>(),
      builder: (context, isOnline) {
        return Scaffold(
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner + avatar + back button
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: screenWidth,
                      height: 180,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primary,
                            primary.withValues(alpha: 0.6),
                            Theme.of(context).colorScheme.primaryContainer,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      left: 8,
                      child: IconButton(
                        icon:
                            const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => context.pop(),
                      ),
                    ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.settings_outlined,
                            color: Colors.white),
                        onPressed: () => context.push('/auth/ui/settings'),
                      ),
                    ),
                    Positioned(
                      bottom: -50,
                      left: screenWidth / 2 - 55,
                      child: GestureDetector(
                        onTap: isOnline ? _pickAndUploadAvatar : null,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              width: 4,
                            ),
                          ),
                          child: ClipOval(
                            child: SizedBox(
                              width: 106,
                              height: 106,
                              child: avatarUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: avatarUrl,
                                      cacheKey: avatarCacheKey,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                        color: primary,
                                        child: const Icon(Icons.person,
                                            size: 50, color: Colors.white54),
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        color: primary,
                                        child: const Icon(Icons.person,
                                            size: 50, color: Colors.white54),
                                      ),
                                    )
                                  : Container(
                                      color: primary,
                                      child: const Icon(Icons.person,
                                          size: 50, color: Colors.white54),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (isOnline)
                      Positioned(
                        bottom: -50,
                        left: screenWidth / 2 + 20,
                        child: GestureDetector(
                          onTap: _pickAndUploadAvatar,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 60),

                Center(
                  child: Column(
                    children: [
                      Text(
                        user?.name ?? '',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      if (!isOnline) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_off,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              'Offline',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                BlocBuilder<PlaylistCubit, PlaylistState>(
                  bloc: playlistCubit,
                  builder: (context, playlistState) {
                    final List<Playlist> playlists =
                        playlistState is PlaylistLoaded
                            ? playlistState.playlists
                            : [];
                    final favoriteCount =
                        profile?['favoriteCount'] ?? 0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildStat(
                                playlists.length.toString(), "Playlists"),
                            const SizedBox(width: 40),
                            _buildStat(
                              favoriteCount.toString(),
                              "Favoritos",
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.05),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Playlists",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (playlists.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 40),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.library_music_outlined,
                                          size: 60,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.3),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          "Nenhuma playlist criada",
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                ...playlists.map((playlist) {
                                  final coverUrl =
                                      playlist.playlistCoverUrl;
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      child: SizedBox(
                                        width: 55,
                                        height: 55,
                                        child: coverUrl.isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl: coverUrl,
                                                cacheKey: coverUrl
                                                    .split('?')
                                                    .first,
                                                fit: BoxFit.cover,
                                                placeholder: (_, __) =>
                                                    Container(
                                                  color: primary.withValues(
                                                      alpha: 0.3),
                                                ),
                                                errorWidget:
                                                    (_, __, ___) =>
                                                        Container(
                                                  color: primary.withValues(
                                                      alpha: 0.3),
                                                  child: const Icon(
                                                      Icons
                                                          .library_music,
                                                      color:
                                                          Colors.white54),
                                                ),
                                              )
                                            : Container(
                                                color: primary.withValues(
                                                    alpha: 0.3),
                                                child: const Icon(
                                                    Icons.library_music,
                                                    color:
                                                        Colors.white54),
                                              ),
                                      ),
                                    ),
                                    title: Text(
                                      playlist.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      '${playlist.totalMusics} música${playlist.totalMusics != 1 ? 's' : ''}',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                    onTap: () => context.push(
                                        '/auth/ui/playlist',
                                        extra: playlist),
                                  );
                                }),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 120),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
