import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:lyria/app/core/services/connectivity/connectivity_service.dart';
import 'package:lyria/app/core/services/http/my_http_client.dart';
import 'package:lyria/app/core/services/storege/my_local_storage.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';

class FavoritesCache {
  final MyLocalStorage storage;
  final MyHttpClient http;
  final ConnectivityService connectivity;

  static const _favoritesKey = 'cached_favorites';
  static const _pendingFavoritesKey = 'pending_favorite_toggles';
  static const _favLocalUpdatedKey = 'favorites_local_updated_at';
  static const _favServerSnapshotKey = 'favorites_server_snapshot_ids';

  FavoritesCache({
    required this.storage,
    required this.http,
    required this.connectivity,
  });

  /// Get favorites from cache
  Future<List<Music>> getCachedFavorites() async {
    final raw = await storage.get(_favoritesKey);
    if (raw == null) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(raw as String);
      return jsonList
          .map((e) => Music.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Save favorites to local cache and update local timestamp
  Future<void> saveFavorites(List<Music> favorites) async {
    await storage.set(
        _favoritesKey, jsonEncode(favorites.map((m) => m.toJson()).toList()));
    await storage.set(
        _favLocalUpdatedKey, DateTime.now().toIso8601String());
  }

  /// Save server snapshot (list of IDs we last saw from server)
  Future<void> _saveServerSnapshot(List<Music> favorites) async {
    final ids = favorites.map((m) => m.id).toList()..sort();
    await storage.set(_favServerSnapshotKey, jsonEncode(ids));
  }

  /// Get last known server snapshot IDs
  Future<List<String>> _getServerSnapshotIds() async {
    final raw = await storage.get(_favServerSnapshotKey);
    if (raw == null) return [];
    try {
      return List<String>.from(jsonDecode(raw as String));
    } catch (_) {
      return [];
    }
  }

  /// Get local updated timestamp
  Future<DateTime?> getLocalUpdatedAt() async {
    final raw = await storage.get(_favLocalUpdatedKey);
    if (raw == null) return null;
    try {
      return DateTime.parse(raw as String);
    } catch (_) {
      return null;
    }
  }

  /// Fetch from server and update cache. Returns cached data if offline.
  Future<List<Music>> fetchAndCacheFavorites() async {
    if (!connectivity.isOnline) {
      return getCachedFavorites();
    }

    try {
      final res = await http.get('/users/favorites');
      if (res['status'] == 200) {
        final list = res['data']['favorites'] as List? ?? [];
        final favorites = list
            .map((m) => Music.fromJson(Map<String, dynamic>.from(m)))
            .toList();
        await storage.set(
            _favoritesKey,
            jsonEncode(favorites.map((m) => m.toJson()).toList()));
        await _saveServerSnapshot(favorites);
        return favorites;
      }
    } catch (_) {}

    return getCachedFavorites();
  }

  /// Fetch server favorites without saving to cache (for conflict detection)
  Future<List<Music>?> fetchServerFavorites() async {
    if (!connectivity.isOnline) return null;
    try {
      final res = await http.get('/users/favorites');
      if (res['status'] == 200) {
        final list = res['data']['favorites'] as List? ?? [];
        return list
            .map((m) => Music.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      }
    } catch (_) {}
    return null;
  }

  /// Toggle favorite locally — always works (online or offline)
  Future<List<Music>> toggleFavorite(
      Music music, List<Music> currentFavorites) async {
    final exists = currentFavorites.any((m) => m.id == music.id);
    List<Music> updated;
    if (exists) {
      updated = currentFavorites.where((m) => m.id != music.id).toList();
    } else {
      updated = [...currentFavorites, music];
    }
    await saveFavorites(updated);
    await _addPendingToggle(music.id);

    if (connectivity.isOnline) {
      try {
        await http.post('/users/favorites/${music.id}');
        await _removePendingToggle(music.id);
      } catch (_) {
        // Keep in pending queue
      }
    }

    return updated;
  }

  /// Remove favorite by index locally
  Future<List<Music>> removeFavorite(
      int index, List<Music> currentFavorites) async {
    if (index < 0 || index >= currentFavorites.length) return currentFavorites;
    final music = currentFavorites[index];
    final updated = List<Music>.from(currentFavorites)..removeAt(index);
    await saveFavorites(updated);
    await _addPendingToggle(music.id);

    if (connectivity.isOnline) {
      try {
        await http.post('/users/favorites/${music.id}');
        await _removePendingToggle(music.id);
      } catch (_) {
        // Keep in pending queue
      }
    }

    return updated;
  }

  /// Check if we have pending changes
  Future<bool> hasPendingChanges() async {
    final pending = await _getPendingToggles();
    return pending.isNotEmpty;
  }

  /// Check if server favorites changed since last sync
  Future<bool> hasServerChanged(List<Music> serverFavorites) async {
    final snapshotIds = await _getServerSnapshotIds();
    final serverIds = serverFavorites.map((m) => m.id).toList()..sort();
    return !listEquals(snapshotIds, serverIds);
  }

  /// Apply pending toggles to server (no conflict)
  Future<void> pushPendingToggles() async {
    if (!connectivity.isOnline) return;

    final pending = await _getPendingToggles();
    if (pending.isEmpty) return;

    final failed = <String>[];
    for (final musicId in pending) {
      try {
        await http.post('/users/favorites/$musicId');
      } catch (_) {
        failed.add(musicId);
      }
    }

    if (failed.isEmpty) {
      await storage.remove(_pendingFavoritesKey);
    } else {
      await storage.set(_pendingFavoritesKey, jsonEncode(failed));
    }

    // Re-fetch from server to ensure consistency
    await fetchAndCacheFavorites();
  }

  /// Accept local version: push local state to server
  Future<void> acceptLocal(
      List<Music> localFavorites, List<Music> serverFavorites) async {
    if (!connectivity.isOnline) return;

    final localIds = localFavorites.map((m) => m.id).toSet();
    final serverIds = serverFavorites.map((m) => m.id).toSet();

    // Toggle items that differ between local and server
    final toAdd = localIds.difference(serverIds);
    final toRemove = serverIds.difference(localIds);

    for (final id in toAdd) {
      try {
        await http.post('/users/favorites/$id');
      } catch (_) {}
    }
    for (final id in toRemove) {
      try {
        await http.post('/users/favorites/$id');
      } catch (_) {}
    }

    await storage.remove(_pendingFavoritesKey);
    await _saveServerSnapshot(localFavorites);
  }

  /// Accept server version: replace local with server data
  Future<List<Music>> acceptServer(List<Music> serverFavorites) async {
    await storage.set(
        _favoritesKey,
        jsonEncode(serverFavorites.map((m) => m.toJson()).toList()));
    await storage.remove(_pendingFavoritesKey);
    await _saveServerSnapshot(serverFavorites);
    await storage.set(
        _favLocalUpdatedKey, DateTime.now().toIso8601String());
    return serverFavorites;
  }

  Future<List<String>> _getPendingToggles() async {
    final raw = await storage.get(_pendingFavoritesKey);
    if (raw == null) return [];
    try {
      return List<String>.from(jsonDecode(raw as String));
    } catch (_) {
      return [];
    }
  }

  Future<void> _addPendingToggle(String musicId) async {
    final pending = await _getPendingToggles();
    if (!pending.contains(musicId)) {
      pending.add(musicId);
    }
    await storage.set(_pendingFavoritesKey, jsonEncode(pending));
  }

  Future<void> _removePendingToggle(String musicId) async {
    final pending = await _getPendingToggles();
    pending.remove(musicId);
    if (pending.isEmpty) {
      await storage.remove(_pendingFavoritesKey);
    } else {
      await storage.set(_pendingFavoritesKey, jsonEncode(pending));
    }
  }
}
