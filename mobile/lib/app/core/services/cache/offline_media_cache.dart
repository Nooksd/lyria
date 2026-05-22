import 'dart:convert';

import 'package:lyria/app/core/services/storege/my_local_storage.dart';
import 'package:lyria/app/modules/download/data/api_download_repo.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';

class OfflineMediaCache {
  final MyLocalStorage storage;
  final ApiDownloadRepo downloadRepo;

  OfflineMediaCache({
    required this.storage,
    required this.downloadRepo,
  });

  String _artistKey(String id) => 'offline_artist_$id';
  String _albumKey(String id) => 'offline_album_$id';
  String _genreKey(String genre) =>
      'offline_genre_${genre.trim().toLowerCase()}';

  Future<void> saveArtist(String id, Map<String, dynamic> data) async {
    await storage.set(_artistKey(id), jsonEncode(data));
  }

  Future<void> saveAlbum(String id, Map<String, dynamic> data) async {
    await storage.set(_albumKey(id), jsonEncode(data));
  }

  Future<void> saveGenre(String genre, Map<String, dynamic> data) async {
    await storage.set(_genreKey(genre), jsonEncode(data));
  }

  Future<Map<String, dynamic>?> getArtist(String id) async {
    return _readMap(_artistKey(id));
  }

  Future<Map<String, dynamic>?> getAlbum(String id) async {
    return _readMap(_albumKey(id));
  }

  Future<Map<String, dynamic>?> getGenre(String genre) async {
    return _readMap(_genreKey(genre));
  }

  Future<Set<String>> getDownloadedIds() async {
    final musics = await downloadRepo.getDownloadedMusics();
    return musics.map((music) => music.id).toSet();
  }

  Future<List<Music>> getDownloadedMusics() {
    return downloadRepo.getDownloadedMusics();
  }

  Future<bool> hasDownloadedMusic(Iterable<Music> musics) async {
    final ids = await getDownloadedIds();
    return musics.any((music) => ids.contains(music.id));
  }

  Future<Map<String, dynamic>?> buildArtistFromDownloads(
      String artistId) async {
    final musics = (await getDownloadedMusics())
        .where((music) => music.artistId == artistId)
        .toList();
    if (musics.isEmpty) return null;

    final albumMap = <String, Map<String, dynamic>>{};
    for (final music in musics) {
      if (music.albumId.isEmpty) continue;
      albumMap.putIfAbsent(
        music.albumId,
        () => {
          '_id': music.albumId,
          'name': music.albumName,
          'albumCoverUrl': music.coverUrl,
          'artistId': music.artistId,
          'artistName': music.artistName,
          'color': music.color,
        },
      );
    }

    final first = musics.first;
    return {
      'artist': {
        '_id': artistId,
        'name': first.artistName,
        'avatarUrl': first.coverUrl,
        'bannerUrl': '',
        'bio': '',
        'color': first.color,
        'genres': musics
            .map((music) => music.genre)
            .where((genre) => genre.isNotEmpty)
            .toSet()
            .toList(),
      },
      'musics': musics.map((music) => music.toJson()).toList(),
      'singles': <Map<String, dynamic>>[],
      'albums': albumMap.values.toList(),
    };
  }

  Future<Map<String, dynamic>?> buildAlbumFromDownloads(String albumId) async {
    final musics = (await getDownloadedMusics())
        .where((music) => music.albumId == albumId)
        .toList();
    if (musics.isEmpty) return null;

    final first = musics.first;
    return {
      'album': {
        '_id': albumId,
        'name': first.albumName,
        'artistId': first.artistId,
        'artistName': first.artistName,
        'albumCoverUrl': first.coverUrl,
        'color': first.color,
        'totalTracks': musics.length,
      },
      'artistName': first.artistName,
      'musics': musics.map((music) => music.toJson()).toList(),
    };
  }

  Future<Map<String, dynamic>?> buildGenreFromDownloads(String genre) async {
    final normalized = genre.trim().toLowerCase();
    final musics = (await getDownloadedMusics())
        .where((music) => music.genre.toLowerCase().contains(normalized))
        .toList();
    if (musics.isEmpty) return null;

    final artistMap = <String, Map<String, dynamic>>{};
    final albumMap = <String, Map<String, dynamic>>{};
    for (final music in musics) {
      artistMap.putIfAbsent(
        music.artistId,
        () => {
          '_id': music.artistId,
          'name': music.artistName,
          'avatarUrl': music.coverUrl,
          'genres': [music.genre],
        },
      );
      if (music.albumId.isNotEmpty) {
        albumMap.putIfAbsent(
          music.albumId,
          () => {
            '_id': music.albumId,
            'name': music.albumName,
            'albumCoverUrl': music.coverUrl,
            'artistId': music.artistId,
            'artistName': music.artistName,
            'color': music.color,
          },
        );
      }
    }

    return {
      'genre': genre,
      'artists': artistMap.values.toList(),
      'albums': albumMap.values.toList(),
      'musics': musics.map((music) => music.toJson()).toList(),
      'total': musics.length,
      'page': 1,
      'limit': musics.length,
    };
  }

  Future<Map<String, dynamic>?> _readMap(String key) async {
    final raw = await storage.get(key);
    if (raw is! String) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }
}
