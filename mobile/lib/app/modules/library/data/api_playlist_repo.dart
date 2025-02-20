import 'package:lyria/app/core/services/http/my_http_client.dart';
import 'package:lyria/app/core/services/storege/my_local_storage.dart';
import 'package:lyria/app/modules/library/domain/entities/playlist.dart';
import 'package:lyria/app/modules/library/domain/repo/playlist_repo.dart';

class ApiPlaylistRepo extends PlaylistRepo {
  final MyHttpClient http;
  final MyLocalStorage storage;

  ApiPlaylistRepo({required this.http, required this.storage});

  @override
  Future<Playlist> createPlaylist(Playlist playlist) {
    // TODO: implement createPlaylist
    throw UnimplementedError();
  }

  @override
  Future<void> deletePlaylist(String id) {
    // TODO: implement deletePlaylist
    throw UnimplementedError();
  }

  @override
  Future<Playlist> getPlaylist(String id) {
    // TODO: implement getPlaylist
    throw UnimplementedError();
  }

  @override
  Future<List<Playlist>> getPlaylists(bool hasToFetch) {
    // TODO: implement getPlaylists
    throw UnimplementedError();
  }

  @override
  Future<Playlist> updatePlaylist(Playlist playlist) {
    // TODO: implement updatePlaylist
    throw UnimplementedError();
  }
}
