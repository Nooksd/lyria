import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lyria/app/core/services/connectivity/connectivity_service.dart';
import 'package:lyria/app/core/services/http/my_http_client.dart';
import 'package:lyria/app/core/services/storege/my_local_storage.dart';
import 'package:lyria/app/modules/library/domain/entities/playlist.dart';
import 'package:lyria/app/modules/library/domain/repo/playlist_repo.dart';

class PendingPlaylistOp {
  final String playlistId;
  final String type; // 'create', 'update', 'delete'
  final String? imagePath; // for offline create with image
  final DateTime timestamp;

  PendingPlaylistOp({
    required this.playlistId,
    required this.type,
    this.imagePath,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'playlistId': playlistId,
        'type': type,
        'imagePath': imagePath,
        'timestamp': timestamp.toIso8601String(),
      };

  factory PendingPlaylistOp.fromJson(Map<String, dynamic> json) =>
      PendingPlaylistOp(
        playlistId: json['playlistId'] as String,
        type: json['type'] as String,
        imagePath: json['imagePath'] as String?,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class ApiPlaylistRepo extends PlaylistRepo {
  final MyHttpClient http;
  final MyLocalStorage storage;
  final ConnectivityService connectivity;

  static const _playlistsKey = 'playlists';
  static const _pendingOpsKey = 'pending_playlist_ops';
  static const _serverSnapshotKey = 'playlists_server_snapshot';
  static const _localUpdatedKey = 'playlists_local_updated_at';

  ApiPlaylistRepo({
    required this.http,
    required this.storage,
    required this.connectivity,
  });

  int _localIdCounter = 0;

  String _generateLocalId() {
    _localIdCounter++;
    return 'local_${DateTime.now().millisecondsSinceEpoch}_$_localIdCounter';
  }

  @override
  Future<Playlist?> createPlaylist(String name) async {
    if (connectivity.isOnline) {
      try {
        final playlistData = jsonEncode({"name": name, "musics": []});
        final response =
            await http.post("/playlist/create", data: playlistData);

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

    // Offline: create locally
    final localId = _generateLocalId();
    final newPlaylist = Playlist(
      id: localId,
      name: name,
      playlistCoverUrl: '',
      musics: [],
      updatedAt: DateTime.now(),
    );

    await _updateStoredPlaylists((playlists) {
      playlists.add(newPlaylist);
      return playlists;
    });
    await _setLocalUpdated();

    await _addPendingOp(PendingPlaylistOp(
      playlistId: localId,
      type: 'create',
      timestamp: DateTime.now(),
    ));

    return newPlaylist;
  }

  @override
  Future<Playlist?> createPlaylistWithImage(
      String name, File imageCover) async {
    if (connectivity.isOnline) {
      final playlist = await createPlaylist(name);
      if (playlist != null) {
        await uploadPlaylistCover(playlist.id, imageCover);
      }
      return playlist;
    }

    // Offline: create local + save image path for later upload
    final localId = _generateLocalId();
    final newPlaylist = Playlist(
      id: localId,
      name: name,
      playlistCoverUrl: '',
      musics: [],
      updatedAt: DateTime.now(),
    );

    await _updateStoredPlaylists((playlists) {
      playlists.add(newPlaylist);
      return playlists;
    });
    await _setLocalUpdated();

    await _addPendingOp(PendingPlaylistOp(
      playlistId: localId,
      type: 'create',
      imagePath: imageCover.path,
      timestamp: DateTime.now(),
    ));

    return newPlaylist;
  }

  @override
  Future<void> deletePlaylist(String id) async {
    // Always remove locally first
    await _updateStoredPlaylists((playlists) {
      playlists.removeWhere((playlist) => playlist.id == id);
      return playlists;
    });
    await _setLocalUpdated();

    if (id.startsWith('local_')) {
      // Remove any pending ops for this local playlist
      await _removePendingOpsForPlaylist(id);
      return;
    }

    if (connectivity.isOnline) {
      try {
        await http.delete("/playlist/delete/$id");
        return;
      } catch (_) {}
    }

    await _addPendingOp(PendingPlaylistOp(
      playlistId: id,
      type: 'delete',
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<Playlist> getPlaylist(String id) async {
    // TODO: implement getPlaylist
    throw UnimplementedError();
  }

  @override
  Future<List<Playlist>> getPlaylists(bool hasToFetch) async {
    try {
      if (hasToFetch && connectivity.isOnline) {
        final response = await http.get("/playlist/get-own");

        if (response['status'] == 200) {
          final data = response["data"] as List<dynamic>;
          final serverPlaylists = data
              .map<Playlist>(
                  (e) => Playlist.fromJson(e as Map<String, dynamic>))
              .toList();

          // Keep local-only playlists
          final cachedPlaylists = await _getCachedPlaylists();
          final localOnly =
              cachedPlaylists.where((p) => p.isLocal).toList();

          final merged = [...serverPlaylists, ...localOnly];
          await _savePlaylists(merged);
          await _saveServerSnapshot(serverPlaylists);
          return merged;
        }
      }

      return await _getCachedPlaylists();
    } catch (e) {
      return await _getCachedPlaylists();
    }
  }

  @override
  Future<Playlist> updatePlaylist(Playlist playlist) async {
    final updated = playlist.copyWith(updatedAt: DateTime.now());

    await _updateStoredPlaylists((playlists) {
      final idx = playlists.indexWhere((p) => p.id == playlist.id);
      if (idx >= 0) {
        playlists[idx] = updated;
      } else {
        playlists.add(updated);
      }
      return playlists;
    });
    await _setLocalUpdated();

    if (playlist.isLocal) {
      // Already has a pending 'create' — the create sync will push latest data
      return updated;
    }

    if (connectivity.isOnline) {
      try {
        final body = jsonEncode({
          'name': updated.name,
          'musics': updated.musics.map((m) => m.id).toList(),
          'isPublic': false,
        });
        await http.put('/playlist/update/${updated.id}', data: body);
        return updated;
      } catch (_) {}
    }

    // Queue update for sync
    await _addPendingOp(PendingPlaylistOp(
      playlistId: updated.id,
      type: 'update',
      timestamp: DateTime.now(),
    ));

    return updated;
  }

  @override
  Future<bool> uploadPlaylistCover(String playlistId, File imageCover) async {
    if (!connectivity.isOnline) {
      // Save image path in pending op
      final ops = await getPendingOps();
      final idx = ops.indexWhere((o) => o.playlistId == playlistId);
      if (idx >= 0) {
        ops[idx] = PendingPlaylistOp(
          playlistId: playlistId,
          type: ops[idx].type,
          imagePath: imageCover.path,
          timestamp: ops[idx].timestamp,
        );
        await _savePendingOps(ops);
      }
      return true; // Will upload on sync
    }

    try {
      final Map<String, dynamic> body = {"playlist": imageCover};
      final response =
          await http.multiPart("/image/playlist/$playlistId", body: body);

      if (response['status'] != 200) {
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
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> saveLastRefreshTime(String lastRefreshTime) {
    storage.set("lastRefreshTime", lastRefreshTime);
    return Future.value();
  }

  // --- Pending operations ---

  Future<List<PendingPlaylistOp>> getPendingOps() async {
    final raw = await storage.get(_pendingOpsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw as String) as List;
      return list
          .map((e) =>
              PendingPlaylistOp.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> hasPendingChanges() async {
    final ops = await getPendingOps();
    return ops.isNotEmpty;
  }

  Future<void> _addPendingOp(PendingPlaylistOp op) async {
    final ops = await getPendingOps();
    // Merge: if there's already an op for this playlist, replace with newer
    ops.removeWhere((o) => o.playlistId == op.playlistId && o.type == op.type);
    // If we're updating something that has a pending create, keep create
    if (op.type == 'update') {
      final hasCreate = ops.any(
          (o) => o.playlistId == op.playlistId && o.type == 'create');
      if (hasCreate) {
        // Don't add separate update, the create will push latest data
        await _savePendingOps(ops);
        return;
      }
    }
    // If deleting a playlist with pending create, remove all ops for it
    if (op.type == 'delete') {
      final hadCreate = ops.any(
          (o) => o.playlistId == op.playlistId && o.type == 'create');
      ops.removeWhere((o) => o.playlistId == op.playlistId);
      if (hadCreate) {
        // Was only local, no need to delete on server
        await _savePendingOps(ops);
        return;
      }
    }
    ops.add(op);
    await _savePendingOps(ops);
  }

  Future<void> _removePendingOpsForPlaylist(String playlistId) async {
    final ops = await getPendingOps();
    ops.removeWhere((o) => o.playlistId == playlistId);
    await _savePendingOps(ops);
  }

  Future<void> _savePendingOps(List<PendingPlaylistOp> ops) async {
    await storage.set(
        _pendingOpsKey, jsonEncode(ops.map((o) => o.toJson()).toList()));
  }

  Future<void> clearPendingOps() async {
    await storage.remove(_pendingOpsKey);
  }

  // --- Server snapshot (for conflict detection) ---

  Future<void> _saveServerSnapshot(List<Playlist> playlists) async {
    final data = playlists.map((p) => p.toJson()).toList();
    await storage.set(_serverSnapshotKey, jsonEncode(data));
  }

  Future<List<Playlist>> getServerSnapshot() async {
    final raw = await storage.get(_serverSnapshotKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw as String) as List;
      return list
          .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetch server playlists without saving to local cache
  Future<List<Playlist>?> fetchServerPlaylists() async {
    if (!connectivity.isOnline) return null;
    try {
      final response = await http.get("/playlist/get-own");
      if (response['status'] == 200) {
        final data = response["data"] as List<dynamic>;
        return data
            .map<Playlist>(
                (e) => Playlist.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return null;
  }

  /// Push a local playlist create to the server
  Future<Playlist?> pushCreate(Playlist localPlaylist, String? imagePath) async {
    try {
      final playlistData =
          jsonEncode({"name": localPlaylist.name, "musics": []});
      final response =
          await http.post("/playlist/create", data: playlistData);

      if (response['status'] == 201) {
        final data = response["data"]["playlist"];
        var serverPlaylist = Playlist.fromJson(data);

        // If there are musics, update them on server
        if (localPlaylist.musics.isNotEmpty) {
          final body = jsonEncode({
            'name': localPlaylist.name,
            'musics': localPlaylist.musics.map((m) => m.id).toList(),
            'isPublic': false,
          });
          await http.put('/playlist/update/${serverPlaylist.id}', data: body);
          serverPlaylist = serverPlaylist.copyWith(
            musics: localPlaylist.musics,
          );
        }

        // Upload image if available
        if (imagePath != null) {
          final file = File(imagePath);
          if (await file.exists()) {
            await uploadPlaylistCover(serverPlaylist.id, file);
          }
        }

        return serverPlaylist;
      }
    } catch (e) {
      debugPrint('[PlaylistRepo] pushCreate error: $e');
    }
    return null;
  }

  /// Push a local playlist update to the server
  Future<bool> pushUpdate(Playlist playlist) async {
    try {
      final body = jsonEncode({
        'name': playlist.name,
        'musics': playlist.musics.map((m) => m.id).toList(),
        'isPublic': false,
      });
      final res = await http.put('/playlist/update/${playlist.id}', data: body);
      return res['error'] == null;
    } catch (_) {
      return false;
    }
  }

  /// Push a local playlist delete to the server
  Future<bool> pushDelete(String playlistId) async {
    try {
      final res = await http.delete("/playlist/delete/$playlistId");
      return res['error'] == null;
    } catch (_) {
      return false;
    }
  }

  /// Accept server playlists (discard local changes for non-local playlists)
  Future<List<Playlist>> acceptServer(List<Playlist> serverPlaylists) async {
    final cached = await _getCachedPlaylists();
    final localOnly = cached.where((p) => p.isLocal).toList();
    final merged = [...serverPlaylists, ...localOnly];
    await _savePlaylists(merged);
    await _saveServerSnapshot(serverPlaylists);
    // Remove update/delete pending ops (keep create ops for local playlists)
    final ops = await getPendingOps();
    ops.removeWhere((o) => !o.playlistId.startsWith('local_'));
    await _savePendingOps(ops);
    return merged;
  }

  // --- Local updated timestamp ---

  Future<DateTime?> getLocalUpdatedAt() async {
    final raw = await storage.get(_localUpdatedKey);
    if (raw == null) return null;
    try {
      return DateTime.parse(raw as String);
    } catch (_) {
      return null;
    }
  }

  Future<void> _setLocalUpdated() async {
    await storage.set(_localUpdatedKey, DateTime.now().toIso8601String());
  }

  // --- Internal helpers ---

  Future<List<Playlist>> _getCachedPlaylists() async {
    final raw = await storage.get(_playlistsKey);
    if (raw == null) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(raw as String);
      return jsonList
          .map<Playlist>(
              (e) => Playlist.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _savePlaylists(List<Playlist> playlists) async {
    await storage.set(_playlistsKey, jsonEncode(playlists));
  }

  Future<List<Playlist>> _updateStoredPlaylists(
      List<Playlist> Function(List<Playlist>) updateFn) async {
    List<Playlist> playlists = await _getCachedPlaylists();
    playlists = updateFn(playlists);
    await _savePlaylists(playlists);
    return playlists;
  }
}
