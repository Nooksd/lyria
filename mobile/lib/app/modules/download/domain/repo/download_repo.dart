import 'package:lyria/app/modules/download/presentation/cubits/download_states.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';

abstract class DownloadRepo {
  Future<void> downloadMusic(Music music);
  Future<void> downloadPlaylist(List<Music> musics);
  Future<bool> isMusicDownloaded(String musicId);
  Future<void> deleteMusic(String musicId);
  Future<DownloadStatus> getDownloadStatus(String musicId);
  Future<List<Music>> getDownloadedMusics();
}
