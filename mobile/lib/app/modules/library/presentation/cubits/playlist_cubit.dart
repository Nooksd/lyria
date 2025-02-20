import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lyria/app/modules/library/domain/entities/playlist.dart';
import 'package:lyria/app/modules/library/domain/repo/playlist_repo.dart';
import 'package:lyria/app/modules/library/presentation/cubits/playlist_states.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';

class PlaylistCubit extends Cubit<PlaylistState> {
  final PlaylistRepo playlistRepo;
  List<Playlist> _playlists = [
    Playlist(
      id: '1',
      name: 'Playlist 1',
      imageUrl: 'http://192.168.1.184:9000/image/cover/teste',
      musics: [
        Music(
          id: '67b0ac6a738371ab88abd6e8',
          name: 'Ivy',
          artistId: '67b09914e7afbb7309a7bd7b',
          artistName: 'Frank Ocean',
          albumId: '67b09968e7afbb7309a7bd7d',
          albumName: 'Blond',
          waveform: [
            0.83,
            0.63,
            0.98,
            0.71,
            0.75,
            0.7,
            0.77,
            0.4,
            0.86,
            0.64,
            0.87,
            0.74,
            0.72,
            0.9,
            0.85,
            0.96,
            0.92,
            0.85,
            0.83,
            0.8,
            0.82,
            0.92,
            0.6,
            0.86,
            0.74,
            0.81,
            0.98,
            0.97,
            1,
            0.65,
            0.65,
            0.78,
            0.69,
            0.9,
            0.77,
            0.91,
            0.76,
            0.83,
            0.63,
            0.26,
            0.2,
            0.33,
            0.64,
            0.26,
            0.63,
            0.46,
            0.93,
            0.73,
            0.84,
            0.69,
            0.67,
            0.88,
            0.83,
            0.71,
            0.7,
            0.31,
            0.59,
            0.93,
            1,
            0.81,
            0.97,
            0.96,
            1,
            0.95,
            0,
            0,
            0.07,
            0.68,
            0.15,
            0,
          ],
          genre: 'Indie',
          url: 'http://192.168.1.184:9000/stream/67b0ac6a738371ab88abd6e8',
          color: '#5C774E',
          coverUrl:
              'http://192.168.1.184:9000/image/cover/67b09968e7afbb7309a7bd7d',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Music(
          id: '67b0ac6a738371ab88abd6e8',
          name: 'Earfquake',
          artistId: '67b09914e7afbb7309a7bd7b',
          artistName: 'Tyler, The Creator',
          albumId: '67b09968e7afbb7309a7bd7d',
          albumName: 'Igor',
          genre: 'Indie',
          url: 'http://192.168.1.184:9000/stream/67b0bbe4738371ab88abd6ee',
          color: '#f3b1c5',
          coverUrl:
              'http://192.168.1.184:9000/image/cover/67b0afda738371ab88abd6eb',
          waveform: [
  	0.05,
					0.03,
					0.09,
					0.02,
					0.15,
					0.15,
					0.08,
					0.04,
					0.8,
					0.78,
					0.82,
					0.85,
					0.84,
					0.85,
					0.81,
					0.91,
					0.81,
					0.8,
					0.87,
					0.96,
					0.8,
					0.93,
					0.79,
					0.82,
					0.86,
					0.14,
					0.91,
					0.75,
					0.96,
					0.92,
					0.96,
					0.75,
					0.74,
					0.74,
					0.75,
					0.48,
					0.1,
					0.2,
					0.37,
					0.21,
					0.23,
					0.26,
					0.19,
					0.01,
					0.81,
					0.77,
					0.88,
					0.76,
					0.87,
					0.9,
					0.86,
					0.81,
					0.1,
					0.84,
					0.87,
					0.96,
					0.78,
					0.89,
					1,
					0.83,
					0.85,
					0.81,
					0.75,
					0.66,
					0.64,
					0.58,
					0.52,
					0.56,
					0.4,
					0.26
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        )
      ],
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
