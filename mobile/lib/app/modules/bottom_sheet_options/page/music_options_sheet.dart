import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/custom/custom_icons.dart';
import 'package:lyria/app/modules/common/music_tile.dart';
import 'package:lyria/app/modules/library/domain/entities/playlist.dart';
import 'package:lyria/app/modules/library/presentation/cubits/playlist_cubit.dart';
import 'package:lyria/app/modules/library/presentation/cubits/playlist_states.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_cubit.dart';

void showMusicOptionsSheet(
  BuildContext context,
  Music music, {
  List<Widget> Function(BuildContext sheetContext)? extraActionsBuilder,
}) {
  final cubit = GetIt.I<MusicCubit>();

  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
    useRootNavigator: true,
    builder: (sheetContext) => Container(
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
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          IgnorePointer(
            child: MusicTile(
              title: music.name,
              subtitle: music.artistName,
              image: music.coverUrl,
              isRound: false,
              onTap: () {},
              trailing: null,
              onLongPress: () {},
            ),
          ),
          const SizedBox(height: 20),
          const Text('Opções'),
          ListTile(
            leading: const Icon(CustomIcons.play),
            title: const Text('Tocar música'),
            onTap: () {
              Navigator.pop(sheetContext);
              cubit.setQueue([music], 0, null);
            },
          ),
          ListTile(
            leading: const Icon(CustomIcons.plus),
            title: const Text('Adicionar a fila'),
            onTap: () {
              Navigator.pop(sheetContext);
              cubit.addToQueue(music);
            },
          ),
          ListTile(
            leading: const Icon(CustomIcons.add_to_playlist),
            title: const Text('Adicionar à playlist'),
            onTap: () {
              Navigator.pop(sheetContext);
              showAddToPlaylistSheet(context, music);
            },
          ),
          ListTile(
            leading: const Icon(CustomIcons.share),
            title: const Text('Compartilhar'),
            onTap: () {
              Navigator.pop(sheetContext);
            },
          ),
          if (extraActionsBuilder != null) ...extraActionsBuilder(sheetContext),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}

void showAddToPlaylistSheet(BuildContext context, Music music) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (_) => _AddToPlaylistSheet(music: music),
  );
}

class _AddToPlaylistSheet extends StatefulWidget {
  final Music music;

  const _AddToPlaylistSheet({required this.music});

  @override
  State<_AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends State<_AddToPlaylistSheet> {
  final PlaylistCubit playlistCubit = getIt<PlaylistCubit>();
  final Set<String> selectedIds = {};
  final Set<String> alreadyAddedIds = {};
  bool initialized = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    playlistCubit.getPlaylists(true);
  }

  void _initializeSelection(List<Playlist> playlists) {
    if (initialized) return;
    for (final playlist in playlists) {
      if (playlist.musics.any((music) => music.id == widget.music.id)) {
        selectedIds.add(playlist.id);
        alreadyAddedIds.add(playlist.id);
      }
    }
    initialized = true;
  }

  Future<void> _save() async {
    if (saving) return;
    setState(() => saving = true);

    final playlists = playlistCubit.playlists;
    var added = 0;
    for (final playlist in playlists) {
      if (!selectedIds.contains(playlist.id) ||
          alreadyAddedIds.contains(playlist.id)) {
        continue;
      }
      final updated =
          await playlistCubit.addMusicToPlaylist(playlist, widget.music);
      if (updated != null) added++;
    }

    if (!mounted || !context.mounted) return;
    final messengerContext = AppRouter.navigatorKey.currentContext;
    Navigator.pop(context);
    if (messengerContext != null) {
      ScaffoldMessenger.of(messengerContext).showSnackBar(
        SnackBar(
          content: Text(
            added == 0
                ? 'Nenhuma playlist alterada'
                : 'Música adicionada em $added playlist${added != 1 ? 's' : ''}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const Spacer(),
                  Text(
                    'Adicionar à playlist',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: saving ? null : _save,
                    child: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Concluir'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              IgnorePointer(
                child: MusicTile(
                  title: widget.music.name,
                  subtitle: widget.music.artistName,
                  image: widget.music.coverUrl,
                  isRound: false,
                  onTap: () {},
                  trailing: null,
                  onLongPress: () {},
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: BlocBuilder<PlaylistCubit, PlaylistState>(
                  bloc: playlistCubit,
                  builder: (context, state) {
                    final playlists = state is PlaylistLoaded
                        ? state.playlists
                        : playlistCubit.playlists;
                    _initializeSelection(playlists);

                    if (playlists.isEmpty) {
                      return const Center(
                        child: Text('Nenhuma playlist criada'),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: playlists.length,
                      itemBuilder: (context, index) {
                        final playlist = playlists[index];
                        final selected = selectedIds.contains(playlist.id);
                        final alreadyAdded =
                            alreadyAddedIds.contains(playlist.id);

                        return CheckboxListTile(
                          value: selected,
                          onChanged: saving || alreadyAdded
                              ? null
                              : (value) {
                                  setState(() {
                                    if (value == true) {
                                      selectedIds.add(playlist.id);
                                    } else {
                                      selectedIds.remove(playlist.id);
                                    }
                                  });
                                },
                          secondary: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: 46,
                              height: 46,
                              child: playlist.playlistCoverUrl.isEmpty
                                  ? Container(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      child: const Icon(CustomIcons.list),
                                    )
                                  : Image.network(
                                      playlist.playlistCoverUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        child: const Icon(CustomIcons.list),
                                      ),
                                    ),
                            ),
                          ),
                          title: Text(playlist.name),
                          subtitle: Text(
                            alreadyAdded
                                ? 'Já contém essa música'
                                : '${playlist.totalMusics} música${playlist.totalMusics != 1 ? 's' : ''}',
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
