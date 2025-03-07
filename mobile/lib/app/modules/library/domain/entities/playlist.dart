import 'package:equatable/equatable.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';

class Playlist extends Equatable {
  final String id;
  final String name;
  final String playlistCoverUrl;
  final List<Music> musics;

  const Playlist({
    required this.id,
    required this.name,
    required this.playlistCoverUrl,
    required this.musics,
  });

  @override
  List<Object?> get props => [id, name, playlistCoverUrl, musics];

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['_id'] as String,
      name: json['name'] as String,
      playlistCoverUrl: json['playlistCoverUrl'] as String,
      musics: json['musics'] == null
          ? []
          : (json['musics'] as List<dynamic>)
              .map((music) => Music.fromJson(music as Map<String, dynamic>))
              .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'playlistCoverUrl': playlistCoverUrl,
      'musics': musics.map((music) => music.toJson()).toList(),
    };
  }
}
