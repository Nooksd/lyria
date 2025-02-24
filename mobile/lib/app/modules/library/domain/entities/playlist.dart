import 'package:equatable/equatable.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';

class Playlist extends Equatable {
  final String id;
  final String name;
  final String playlistCoverUrl;
  final List<Music> musics;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Playlist({
    required this.id,
    required this.name,
    required this.playlistCoverUrl,
    required this.musics,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props =>
      [id, name, playlistCoverUrl, musics, createdAt, updatedAt];

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
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'playlistCoverUrl': playlistCoverUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'musics': musics.map((music) => music.toJson()).toList(),
    };
  }
}
