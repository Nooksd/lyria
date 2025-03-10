import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lyria/app/modules/library/domain/entities/playlist.dart';
import 'package:lyria/app/modules/library/domain/repo/playlist_repo.dart';
import 'package:lyria/app/modules/library/presentation/cubits/playlist_states.dart';

class PlaylistCubit extends Cubit<PlaylistState> {
  final PlaylistRepo playlistRepo;

  DateTime _lastRefreshTime = DateTime.now();
  List<Playlist> _playlists = [];

  PlaylistCubit({required this.playlistRepo}) : super(PlaylistInitial()) {
    _loadLastRefreshTime();
  }

  String get cacheBuster => _lastRefreshTime.toIso8601String();

  Future<void> _loadLastRefreshTime() async {
    final savedTime = await playlistRepo.getLastRefreshTime();

    if (savedTime != null) {
      _lastRefreshTime = DateTime.parse(savedTime);
    }
  }

  Future<void> _saveLastRefreshTime() async {
    await playlistRepo.saveLastRefreshTime(_lastRefreshTime.toIso8601String());
  }

  Future<void> getPlaylists(bool hasToFetch) async {
    if (hasToFetch) {
      _lastRefreshTime = DateTime.now();
      await _saveLastRefreshTime();
    }

    emit(PlaylistLoading());
    final playlists = await playlistRepo.getPlaylists(hasToFetch);

    _playlists = playlists;
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
