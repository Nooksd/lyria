import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/modules/auth/presentation/cubits/auth_cubit.dart';
import 'package:lyria/app/core/services/http/my_http_client.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final AuthCubit authCubit = getIt<AuthCubit>();
  final MyHttpClient http = getIt<MyHttpClient>();
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _bioController;

  bool _isSaving = false;
  String? _avatarCacheBuster;

  @override
  void initState() {
    super.initState();
    final user = authCubit.currentUser;
    _nameController = TextEditingController(text: user?.name ?? '');
    _bioController = TextEditingController();
    _loadBio();
  }

  Future<void> _loadBio() async {
    final user = authCubit.currentUser;
    if (user == null) return;
    try {
      final res = await http.get('/users/profile/${user.uid}');
      if (res['status'] == 200 && mounted) {
        setState(() {
          _bioController.text = res['data']['bio'] ?? '';
        });
      }
    } catch (_) {}
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

      final user = authCubit.currentUser;
      if (user != null && user.avatarUrl.isNotEmpty) {
        await DefaultCacheManager().removeFile(user.avatarUrl);
      }

      setState(() {
        _avatarCacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto atualizada!')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao enviar foto')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    final user = authCubit.currentUser;
    if (user == null) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O nome não pode estar vazio')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await http.put('/users/update/${user.uid}', data: {
        'name': name,
        'bio': _bioController.text.trim(),
      });

      authCubit.checkAuth();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil atualizado!')),
        );
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao salvar perfil')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final user = authCubit.currentUser;
    final primary = Theme.of(context).colorScheme.primary;

    final avatarUrl = user != null && user.avatarUrl.isNotEmpty
        ? (_avatarCacheBuster != null
            ? '${user.avatarUrl}?v=$_avatarCacheBuster'
            : user.avatarUrl)
        : '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text("Editar Perfil"),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primary,
                    ),
                  )
                : Text(
                    "Salvar",
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Avatar
            GestureDetector(
              onTap: _pickAndUploadAvatar,
              child: Stack(
                children: [
                  ClipOval(
                    child: Container(
                      width: 110,
                      height: 110,
                      color: primary,
                      child: avatarUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: avatarUrl,
                              fit: BoxFit.cover,
                              fadeInDuration: Duration.zero,
                              fadeOutDuration: Duration.zero,
                              placeholder: (_, __) => const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.white54),
                              errorWidget: (_, __, ___) => const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.white54),
                            )
                          : const Icon(Icons.person,
                              size: 50, color: Colors.white54),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt,
                          size: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Name field
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: "Nome",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            // Bio field
            TextField(
              controller: _bioController,
              maxLines: 3,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: "Bio",
                hintText: "Conte um pouco sobre você...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.edit_outlined),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
