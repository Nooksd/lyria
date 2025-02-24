import 'dart:io';

import 'package:lyria/app/modules/library/domain/entities/playlist.dart';

abstract class PlaylistRepo {
  Future<List<Playlist>> getPlaylists(bool hasToFetch);
  Future<Playlist> getPlaylist(String id);
  Future<Playlist?> createPlaylist(String name);
  Future<Playlist> updatePlaylist(Playlist playlist);
  Future<void> deletePlaylist(String id);
  Future<void> uploadPlaylistCover(String playlistId, File imageCover);
}
