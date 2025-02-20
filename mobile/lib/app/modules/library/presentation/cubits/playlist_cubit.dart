import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lyria/app/modules/library/domain/entities/playlist.dart';
import 'package:lyria/app/modules/library/domain/repo/playlist_repo.dart';
import 'package:lyria/app/modules/library/presentation/cubits/playlist_states.dart';

class PlaylistCubit extends Cubit<PlaylistState> {
  final PlaylistRepo playlistRepo;
  List<Playlist> _playlists = [
    Playlist(
      id: '1',
      name: 'Playlist 1',
      imageUrl: 'http://192.168.1.55:9000/image/cover/teste',
      musics: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  PlaylistCubit({required this.playlistRepo}) : super(PlaylistInitial());

  Future<void> getPlaylists() async {
    emit(PlaylistLoading());
    // final playlists = await playlistRepo.getPlaylists(_playlists.isEmpty);
    _playlists = playlists;
    emit(PlaylistLoaded(playlists));
  }

  Future<void> createPlaylist(Playlist playlist) async {
    emit(PlaylistLoading());
    final newPlaylist = await playlistRepo.createPlaylist(playlist);
    _playlists.add(newPlaylist);
    emit(PlaylistLoaded(_playlists));
  }

  Future<void> deletePlaylist(String id) async {
    emit(PlaylistLoading());
    await playlistRepo.deletePlaylist(id);
    _playlists.removeWhere((playlist) => playlist.id == id);
    emit(PlaylistLoaded(_playlists));
  }

  Future<void> updatePlaylist(Playlist playlist) async {
    emit(PlaylistLoading());
    await playlistRepo.updatePlaylist(playlist);
    _playlists.removeWhere((playlist) => playlist.id == playlist.id);
    _playlists.add(playlist);
    emit(PlaylistLoaded(_playlists));
  }

  List<Playlist> get playlists => _playlists;
}
