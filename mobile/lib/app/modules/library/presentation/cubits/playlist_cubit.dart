import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lyria/app/modules/library/domain/entities/playlist.dart';
import 'package:lyria/app/modules/library/domain/repo/playlist_repo.dart';
import 'package:lyria/app/modules/library/presentation/cubits/playlist_states.dart';

class PlaylistCubit extends Cubit<PlaylistState> {
  final PlaylistRepo playlistRepo;
  List<Playlist> _playlists = [];

  PlaylistCubit({required this.playlistRepo}) : super(PlaylistInitial());

  Future<void> getPlaylists(bool hasToFetch) async {
    emit(PlaylistLoading());
    final playlists =
        await playlistRepo.getPlaylists(_playlists.isEmpty || hasToFetch);

    _playlists = playlists;

    print(playlists);
    emit(PlaylistLoaded(playlists));
  }

  Future<void> createPlaylist(String name, File? imageCover) async {
    emit(PlaylistLoading());
    final newPlaylist = await playlistRepo.createPlaylist(name);

    if (newPlaylist == null) return;

    if (imageCover != null) {
      _uploadCover(newPlaylist.id, imageCover);
    }

    _playlists.add(newPlaylist);
    emit(PlaylistLoaded(_playlists));
  }

  Future<void> deletePlaylist(String id) async {
    emit(PlaylistLoading());
    await playlistRepo.deletePlaylist(id);
    _playlists.removeWhere((playlist) => playlist.id == id);
    emit(PlaylistLoaded(_playlists));
  }

  Future<void> updatePlaylist(Playlist playlist) async {
    emit(PlaylistLoading());
    await playlistRepo.updatePlaylist(playlist);
    _playlists.removeWhere((playlist) => playlist.id == playlist.id);
    _playlists.add(playlist);
    emit(PlaylistLoaded(_playlists));
  }

  Future<void> _uploadCover(String playlistId, File imageCover) async {
    await playlistRepo.uploadPlaylistCover(playlistId, imageCover);
  }

  List<Playlist> get playlists => _playlists;
}
