import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lyria/app/core/services/connectivity/connectivity_service.dart';
import 'package:lyria/app/modules/library/domain/entities/playlist.dart';
import 'package:lyria/app/modules/library/domain/repo/playlist_repo.dart';
import 'package:lyria/app/modules/library/presentation/cubits/playlist_states.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';

class PlaylistCubit extends Cubit<PlaylistState> {
  final PlaylistRepo playlistRepo;
  final ConnectivityService connectivity;

  DateTime _lastRefreshTime = DateTime.now();
  List<Playlist> _playlists = [];

  PlaylistCubit({required this.playlistRepo, required this.connectivity})
      : super(PlaylistInitial()) {
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
    // If offline, always load from cache
    if (!connectivity.isOnline) {
      hasToFetch = false;
    }

    // Load cache first (no loading spinner)
    final cached = await playlistRepo.getPlaylists(false);
    _playlists = cached;
    emit(PlaylistLoaded(List.from(_playlists)));

    if (hasToFetch) {
      _lastRefreshTime = DateTime.now();
      await _saveLastRefreshTime();
      final fresh = await playlistRepo.getPlaylists(true);
      _playlists = fresh;
      emit(PlaylistLoaded(List.from(_playlists)));
    }
  }

  Future<void> createPlaylist(String name, File? imageCover) async {
    Playlist? newPlaylist;
    if (imageCover != null) {
      newPlaylist = await playlistRepo.createPlaylistWithImage(name, imageCover);
    } else {
      newPlaylist = await playlistRepo.createPlaylist(name);
    }

    if (newPlaylist == null) return;

    _playlists.add(newPlaylist);
    emit(PlaylistLoaded(List.from(_playlists)));
  }

  Future<void> deletePlaylist(String id) async {
    await playlistRepo.deletePlaylist(id);
    _playlists.removeWhere((playlist) => playlist.id == id);
    emit(PlaylistLoaded(List.from(_playlists)));
  }

  Future<void> updatePlaylist(Playlist playlist) async {
    await playlistRepo.updatePlaylist(playlist);
    final idx = _playlists.indexWhere((p) => p.id == playlist.id);
    if (idx >= 0) {
      _playlists[idx] = playlist;
      emit(PlaylistLoaded(List.from(_playlists)));
    }
  }

  Future<Playlist?> addMusicToPlaylist(Playlist playlist, Music music) async {
    if (playlist.musics.any((m) => m.id == music.id)) return playlist;
    final updated = playlist.copyWith(
      musics: [...playlist.musics, music],
      updatedAt: DateTime.now(),
    );
    await playlistRepo.updatePlaylist(updated);
    final idx = _playlists.indexWhere((p) => p.id == playlist.id);
    if (idx >= 0) {
      _playlists[idx] = updated;
      emit(PlaylistLoaded(List.from(_playlists)));
    }
    return updated;
  }

  Future<Playlist?> removeMusicFromPlaylist(Playlist playlist, String musicId) async {
    final updatedMusics = playlist.musics.where((m) => m.id != musicId).toList();
    final updated = playlist.copyWith(
      musics: updatedMusics,
      updatedAt: DateTime.now(),
    );
    await playlistRepo.updatePlaylist(updated);
    final idx = _playlists.indexWhere((p) => p.id == playlist.id);
    if (idx >= 0) {
      _playlists[idx] = updated;
      emit(PlaylistLoaded(List.from(_playlists)));
    }
    return updated;
  }

  void replaceLocalPlaylist(String localId, Playlist serverPlaylist) {
    final idx = _playlists.indexWhere((p) => p.id == localId);
    if (idx >= 0) {
      _playlists[idx] = serverPlaylist;
      emit(PlaylistLoaded(List.from(_playlists)));
    }
  }

  List<Playlist> get playlists => _playlists;
}
