import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lyria/app/core/services/download/download_service.dart';
import 'package:lyria/app/modules/download/presentation/cubits/download_states.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';

class DownloadCubit extends Cubit<Map<String, DownloadStatus>> {
  final DownloadService downloadService;

  DownloadCubit({required this.downloadService}) : super({});

  Future<bool> isMusicDownloaded(String musicId) async {
    return await downloadService.isFileDownloaded('$musicId.mp3');
  }

  Future<void> downloadMusic(String id, String url) async {
    emit({...state, id: DownloadStatus.downloading});
    try {
      await downloadService.downloadFile(url, '$id.mp3');
      emit({...state, id: DownloadStatus.downloaded});
    } catch (e) {
      emit({...state, id: DownloadStatus.error});
    }
  }

  Future<void> downloadPlaylist(List<Music> musics) async {
    for (final music in musics) {
      final downloaded = await isMusicDownloaded(music.id);
      if (!downloaded) {
        await downloadMusic(music.id, music.url);
      }
    }
  }
}
