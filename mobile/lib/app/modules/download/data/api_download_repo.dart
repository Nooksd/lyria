import 'dart:convert';
import 'dart:io';
import 'package:lyria/app/core/services/download/download_service.dart';
import 'package:lyria/app/core/services/storege/my_local_storage.dart';
import 'package:lyria/app/modules/download/domain/repo/download_repo.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';
import 'package:lyria/app/modules/download/presentation/cubits/download_states.dart';

class ApiDownloadRepo implements DownloadRepo {
  final DownloadService downloadService;
  final MyLocalStorage storage;

  ApiDownloadRepo({required this.downloadService, required this.storage});

  @override
  Future<void> downloadMusic(Music music) async {
    final fileName = '${music.id}.mp3';
    storage.set(music.id, DownloadStatus.downloading.index);

    try {
      await downloadService.downloadFile(music.url, fileName);
      storage.set(music.id, DownloadStatus.downloaded.index);
      storage.set('dl_meta_${music.id}', jsonEncode(music.toJson()));
    } catch (_) {
      storage.set(music.id, DownloadStatus.error.index);
    }
  }

  @override
  Future<void> downloadPlaylist(List<Music> musics) async {
    for (final music in musics) {
      final isDownloaded = await isMusicDownloaded(music.id);
      if (!isDownloaded) {
        await downloadMusic(music);
      }
    }
  }

  @override
  Future<bool> isMusicDownloaded(String musicId) async {
    return await downloadService.isFileDownloaded('$musicId.mp3');
  }

  @override
  Future<void> deleteMusic(String musicId) async {
    final filePath = await downloadService.getFilePath('$musicId.mp3');
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
    await storage.remove(musicId);
    await storage.remove('dl_meta_$musicId');
  }

  @override
  Future<void> clearDownloads() async {
    final fileNames = await downloadService.listDownloadedFileNames();
    for (final name in fileNames) {
      final musicId = name.replaceAll('.mp3', '');
      await deleteMusic(musicId);
    }
  }

  @override
  Future<int> getDownloadedBytes() async {
    final fileNames = await downloadService.listDownloadedFileNames();
    var total = 0;
    for (final name in fileNames) {
      final file = File(await downloadService.getFilePath(name));
      if (await file.exists()) {
        total += await file.length();
      }
    }
    return total;
  }

  @override
  Future<List<Music>> getDownloadedMusics() async {
    final fileNames = await downloadService.listDownloadedFileNames();
    final List<Music> musics = [];
    for (final name in fileNames) {
      final musicId = name.replaceAll('.mp3', '');
      final metaJson = await storage.get('dl_meta_$musicId');
      if (metaJson is String) {
        try {
          musics.add(Music.fromJson(jsonDecode(metaJson)));
        } catch (_) {}
      }
    }
    return musics;
  }

  @override
  Future<DownloadStatus> getDownloadStatus(String musicId) async {
    final storedValue = await storage.get(musicId);
    if (storedValue is int &&
        storedValue >= 0 &&
        storedValue < DownloadStatus.values.length) {
      final storedStatus = DownloadStatus.values[storedValue];
      if (storedStatus != DownloadStatus.downloaded) {
        return storedStatus;
      }

      final isDownloaded = await isMusicDownloaded(musicId);
      if (isDownloaded) return DownloadStatus.downloaded;

      await storage.remove(musicId);
      await storage.remove('dl_meta_$musicId');
      return DownloadStatus.notDownloaded;
    }

    final isDownloaded = await isMusicDownloaded(musicId);
    return isDownloaded
        ? DownloadStatus.downloaded
        : DownloadStatus.notDownloaded;
  }
}
