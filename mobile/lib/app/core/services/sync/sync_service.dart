import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lyria/app/app_router.dart';
import 'package:lyria/app/core/services/cache/favorites_cache.dart';
import 'package:lyria/app/core/services/connectivity/connectivity_service.dart';
import 'package:lyria/app/core/services/sync/sync_dialog.dart';
import 'package:lyria/app/modules/library/data/api_playlist_repo.dart';
import 'package:lyria/app/modules/library/domain/entities/playlist.dart';
import 'package:lyria/app/modules/library/presentation/cubits/playlist_cubit.dart';

class SyncService {
  final ConnectivityService connectivity;
  final FavoritesCache favoritesCache;
  final PlaylistCubit playlistCubit;
  final ApiPlaylistRepo playlistRepo;

  StreamSubscription<bool>? _sub;
  bool _isSyncing = false;

  SyncService({
    required this.connectivity,
    required this.favoritesCache,
    required this.playlistCubit,
    required this.playlistRepo,
  });

  void init() {
    _sub = connectivity.onStatusChange.listen((isOnline) {
      if (isOnline) {
        _syncAll();
      }
    });
  }

  Future<void> _syncAll() async {
    if (_isSyncing) return;
    _isSyncing = true;

    debugPrint('[Sync] Back online — syncing...');

    try {
      await _syncFavorites();
    } catch (e) {
      debugPrint('[Sync] Favorites sync error: $e');
    }

    try {
      await _syncPlaylists();
    } catch (e) {
      debugPrint('[Sync] Playlists sync error: $e');
    }

    debugPrint('[Sync] Sync complete');
    _isSyncing = false;
  }

  // --- Favorites Sync ---

  Future<void> _syncFavorites() async {
    final hasPending = await favoritesCache.hasPendingChanges();

    if (!hasPending) {
      // No local changes, just refresh from server
      await favoritesCache.fetchAndCacheFavorites();
      return;
    }

    // We have pending changes — check if server changed too
    final serverFavorites = await favoritesCache.fetchServerFavorites();
    if (serverFavorites == null) return; // Can't reach server

    final serverChanged =
        await favoritesCache.hasServerChanged(serverFavorites);

    if (!serverChanged) {
      // Server didn't change, just push our toggles
      await favoritesCache.pushPendingToggles();
      return;
    }

    // CONFLICT: both sides changed
    final localFavorites = await favoritesCache.getCachedFavorites();
    final localUpdatedAt = await favoritesCache.getLocalUpdatedAt();

    final choice = await _showConflictDialog(
      SyncConflictInfo(
        title: 'Conflito nos Favoritos',
        description:
            'Os favoritos foram modificados tanto localmente quanto no servidor. Qual versão deseja manter?',
        localUpdatedAt: localUpdatedAt,
        serverUpdatedAt: DateTime.now(),
      ),
    );

    if (choice == SyncChoice.local) {
      await favoritesCache.acceptLocal(localFavorites, serverFavorites);
    } else {
      await favoritesCache.acceptServer(serverFavorites);
    }
  }

  // --- Playlists Sync ---

  Future<void> _syncPlaylists() async {
    final hasPending = await playlistRepo.hasPendingChanges();

    if (!hasPending) {
      // No local changes, just refresh from server
      await playlistCubit.getPlaylists(true);
      return;
    }

    final pendingOps = await playlistRepo.getPendingOps();
    final serverPlaylists = await playlistRepo.fetchServerPlaylists();
    if (serverPlaylists == null) return;

    // Process creates first
    final creates =
        pendingOps.where((o) => o.type == 'create').toList();
    for (final op in creates) {
      final cached = playlistCubit.playlists
          .where((p) => p.id == op.playlistId)
          .firstOrNull;
      if (cached == null) continue;

      final serverPlaylist =
          await playlistRepo.pushCreate(cached, op.imagePath);
      if (serverPlaylist != null) {
        // Replace local ID with server ID in cached playlists
        playlistCubit.replaceLocalPlaylist(op.playlistId, serverPlaylist);
      }
    }

    // Process deletes
    final deletes =
        pendingOps.where((o) => o.type == 'delete').toList();
    for (final op in deletes) {
      await playlistRepo.pushDelete(op.playlistId);
    }

    // Process updates — check for conflicts
    final updates =
        pendingOps.where((o) => o.type == 'update').toList();
    if (updates.isNotEmpty) {
      final snapshot = await playlistRepo.getServerSnapshot();

      bool hasConflict = false;
      for (final op in updates) {
        final serverVersion = serverPlaylists
            .where((p) => p.id == op.playlistId)
            .firstOrNull;
        final snapshotVersion =
            snapshot.where((p) => p.id == op.playlistId).firstOrNull;

        if (serverVersion == null) continue;
        if (snapshotVersion == null ||
            !_playlistDataEquals(serverVersion, snapshotVersion)) {
          hasConflict = true;
          break;
        }
      }

      if (hasConflict) {
        final localUpdatedAt = await playlistRepo.getLocalUpdatedAt();

        final choice = await _showConflictDialog(
          SyncConflictInfo(
            title: 'Conflito nas Playlists',
            description:
                'As playlists foram modificadas tanto localmente quanto no servidor. Qual versão deseja manter?',
            localUpdatedAt: localUpdatedAt,
            serverUpdatedAt: DateTime.now(),
          ),
        );

        if (choice == SyncChoice.local) {
          // Push all local updates to server
          for (final op in updates) {
            final localVersion = playlistCubit.playlists
                .where((p) => p.id == op.playlistId)
                .firstOrNull;
            if (localVersion != null) {
              await playlistRepo.pushUpdate(localVersion);
            }
          }
        } else {
          await playlistRepo.acceptServer(serverPlaylists);
        }
      } else {
        // No conflict — push updates
        for (final op in updates) {
          final localVersion = playlistCubit.playlists
              .where((p) => p.id == op.playlistId)
              .firstOrNull;
          if (localVersion != null) {
            await playlistRepo.pushUpdate(localVersion);
          }
        }
      }
    }

    await playlistRepo.clearPendingOps();
    await playlistCubit.getPlaylists(true);
  }

  bool _playlistDataEquals(Playlist a, Playlist b) {
    if (a.name != b.name) return false;
    final aIds = a.musics.map((m) => m.id).toList()..sort();
    final bIds = b.musics.map((m) => m.id).toList()..sort();
    return listEquals(aIds, bIds);
  }

  Future<SyncChoice> _showConflictDialog(SyncConflictInfo info) async {
    final context = AppRouter.navigatorKey.currentContext;
    if (context == null) return SyncChoice.server;

    final choice = await SyncDialog.showConflict(context, info);
    return choice ?? SyncChoice.server;
  }

  void dispose() {
    _sub?.cancel();
  }
}
