import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/library/domain/entities/playlist.dart';
import 'package:lyria/app/modules/library/presentation/cubits/playlist_cubit.dart';
import 'package:lyria/app/modules/ui/includes/custom_appbar.dart';

class AddPlaylist extends StatefulWidget {
  final Playlist? playlist;

  const AddPlaylist({super.key, this.playlist});

  @override
  State<AddPlaylist> createState() => _AddPlaylistState();
}

class _AddPlaylistState extends State<AddPlaylist> {
  final PlaylistCubit cubit = getIt<PlaylistCubit>();
  final TextEditingController _playlistName = TextEditingController();
  File? selectedImage;
  bool isLoading = false;
  bool get isEditing => widget.playlist != null;

  @override
  void initState() {
    super.initState();
    if (widget.playlist != null) {
      _playlistName.text = widget.playlist!.name;
    }
  }

  @override
  void dispose() {
    _playlistName.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitPlaylist() async {
    final name = _playlistName.text.trim();
    if (name.isEmpty) return;

    setState(() {
      isLoading = true;
    });

    Playlist? savedPlaylist;
    if (isEditing) {
      savedPlaylist = await cubit.updatePlaylistDetails(
          widget.playlist!, name, selectedImage);
    } else {
      await cubit.createPlaylist(name, selectedImage);
    }

    if (mounted) {
      context.pop(savedPlaylist);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final coverProvider = selectedImage != null
        ? FileImage(selectedImage!) as ImageProvider<Object>
        : widget.playlist?.playlistCoverUrl.isNotEmpty == true
            ? CachedNetworkImageProvider(widget.playlist!.playlistCoverUrl)
                as ImageProvider<Object>
            : const AssetImage('assets/images/default.png');

    return Scaffold(
      appBar: CustomAppBar(),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: screenWidth * 0.05,
              left: screenWidth * 0.05,
              child: SizedBox(
                width: 25,
                height: 30,
                child: IconButton(
                  onPressed: () => context.pop(),
                  icon: Icon(
                    CustomIcons.goback,
                    size: 25,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              left: 0,
              top: 0,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: pickImage, // Permite escolher a imagem
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          image: DecorationImage(
                            image: coverProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 30),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 50),
                      child: TextField(
                        controller: _playlistName,
                        maxLength: 40,
                        decoration: InputDecoration(
                          labelText: 'Nome da Playlist',
                          labelStyle: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 30),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 30,
                      children: [
                        GestureDetector(
                          onTap: () {
                            context.pop();
                          },
                          child: Container(
                            width: 130,
                            height: 55,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            child: Center(
                              child: Text("Cancelar"),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _submitPlaylist,
                          child: Container(
                            width: 130,
                            height: 55,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Center(
                              child: Text(
                                isEditing ? "Salvar" : "Criar",
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (isLoading)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Center(
                    child: SizedBox(
                      width: 150,
                      child: Lottie.asset(
                        'assets/animations/loading.json',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
