import 'package:lyria/app/modules/library/domain/entities/playlist.dart';

abstract class PlaylistState {}

class PlaylistInitial extends PlaylistState {}

class PlaylistLoading extends PlaylistState {}

class PlaylistLoaded extends PlaylistState {
  final List<Playlist> playlists;
  PlaylistLoaded(this.playlists);
}

class PlaylistError extends PlaylistState {
  final String error;
  PlaylistError(this.error);
}
