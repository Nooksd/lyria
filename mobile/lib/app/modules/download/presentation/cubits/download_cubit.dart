import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lyria/app/modules/download/domain/repo/download_repo.dart';
import 'package:lyria/app/modules/download/presentation/cubits/download_states.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';

class DownloadCubit extends Cubit<Map<String, DownloadStatus>> {
  final DownloadRepo downloadRepo;

  DownloadCubit({required this.downloadRepo}) : super({});

  Future<void> loadDownloadStatus(String musicId) async {
    final status = await downloadRepo.getDownloadStatus(musicId);
    emit({...state, musicId: status});
  }

  Future<void> downloadMusic(Music music) async {
    emit({...state, music.id: DownloadStatus.downloading});
    try {
      await downloadRepo.downloadMusic(music);
      emit({...state, music.id: DownloadStatus.downloaded});
    } catch (e) {
      emit({...state, music.id: DownloadStatus.error});
    }
  }

  Future<void> downloadPlaylist(List<Music> musics) async {
    for (final music in musics) {
      final isDownloaded = await downloadRepo.isMusicDownloaded(music.id);
      if (!isDownloaded) {
        await downloadMusic(music);
      }
    }
  }

  Future<void> deleteMusic(String musicId) async {
    await downloadRepo.deleteMusic(musicId);
    emit({...state, musicId: DownloadStatus.notDownloaded});
  }

  Future<void> loadPlaylistStatuses(List<String> musicIds) async {
    final Map<String, DownloadStatus> updates = {};
    for (final id in musicIds) {
      updates[id] = await downloadRepo.getDownloadStatus(id);
    }
    if (updates.isNotEmpty) emit({...state, ...updates});
  }

  PlaylistDownloadStatus getPlaylistStatus(List<String> musicIds) {
    if (musicIds.isEmpty) return PlaylistDownloadStatus.notDownloaded;
    final statuses =
        musicIds.map((id) => state[id] ?? DownloadStatus.notDownloaded).toList();
    if (statuses.any((s) => s == DownloadStatus.downloading)) {
      return PlaylistDownloadStatus.downloading;
    }
    if (statuses.every((s) => s == DownloadStatus.downloaded)) {
      return PlaylistDownloadStatus.downloaded;
    }
    return PlaylistDownloadStatus.notDownloaded;
  }
}
