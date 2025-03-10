import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lyria/app/core/services/http/my_http_client.dart';
import 'package:lyria/app/core/services/storege/my_local_storage.dart';
import 'package:lyria/app/modules/library/domain/entities/playlist.dart';
import 'package:lyria/app/modules/library/domain/repo/playlist_repo.dart';

class ApiPlaylistRepo extends PlaylistRepo {
  final MyHttpClient http;
  final MyLocalStorage storage;

  ApiPlaylistRepo({required this.http, required this.storage});

  @override
  Future<Playlist?> createPlaylist(String name) async {
    try {
      final playlistData = jsonEncode({"name": name, "musics": []});
      final response = await http.post("/playlist/create", data: playlistData);

      if (response['status'] == 201) {
        final data = response["data"]["playlist"];
        final newPlaylist = Playlist.fromJson(data);

        await _updateStoredPlaylists((playlists) {
          playlists.add(newPlaylist);
          return playlists;
        });

        return newPlaylist;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> deletePlaylist(String id) async {
    try {
      await http.delete("/playlist/delete/$id");
      await _updateStoredPlaylists((playlists) {
        playlists.removeWhere((playlist) => playlist.id == id);
        return playlists;
      });
    } catch (e) {
      debugPrint(e.toString());
      throw Exception(e);
    }
  }

  @override
  Future<Playlist> getPlaylist(String id) async {
    // TODO: implement getPlaylist
    throw UnimplementedError();
  }

  @override
  Future<List<Playlist>> getPlaylists(bool hasToFetch) async {
    try {
      if (hasToFetch) {
        final response = await http.get("/playlist/get-own");

        if (response['status'] == 200) {
          final data = response["data"] as List<dynamic>;

          if (data.isNotEmpty) {
            await storage.set("playlists", jsonEncode(data));
            return data
                .map<Playlist>(
                    (e) => Playlist.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        }
      } else {
        final playlist = await storage.get("playlists");
        if (playlist != null) {
          final List<dynamic> jsonList = jsonDecode(playlist as String);
          return jsonList
              .map<Playlist>(
                  (e) => Playlist.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  Future<Playlist> updatePlaylist(Playlist playlist) async {
    // TODO: implement updatePlaylist
    throw UnimplementedError();
  }

  @override
  Future<bool> uploadPlaylistCover(String playlistId, File imageCover) async {
    try {
      final Map<String, dynamic> body = {"playlist": imageCover};
      final response =
          await http.multiPart("/image/playlist/$playlistId", body: body);

      if (response['status'] != 200) {
        await deletePlaylist(playlistId);
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String?> getLastRefreshTime() async {
    try {
      final lastRefreshTime = await storage.get("lastRefreshTime");
      if (lastRefreshTime != null) {
        return lastRefreshTime;
      }

      return Future.value(null);
    } catch (e) {
      return Future.value(null);
    }
  }

  @override
  Future<void> saveLastRefreshTime(String lastRefreshTime) {
    storage.set("lastRefreshTime", lastRefreshTime);
    return Future.value();
  }

  Future<List<Playlist>> _updateStoredPlaylists(
      List<Playlist> Function(List<Playlist>) updateFn) async {
    List<Playlist> playlists = [];

    final stored = await storage.get("playlists");

    if (stored != null) {
      final List<dynamic> jsonList = jsonDecode(stored as String);
      playlists = jsonList
          .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    playlists = updateFn(playlists);

    await storage.set("playlists", jsonEncode(playlists));
    return playlists;
  }
}
