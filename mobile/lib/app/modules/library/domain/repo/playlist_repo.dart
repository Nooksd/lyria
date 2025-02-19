
import 'package:lyria/app/modules/library/domain/entities/playlist.dart';

abstract class PlaylistRepo {
  Future<List<Playlist>> getPlaylists();
  Future<Playlist> getPlaylist(String id);
  Future<Playlist> createPlaylist(Playlist playlist);
  Future<Playlist> updatePlaylist(Playlist playlist);
  Future<void> deletePlaylist(String id);
}