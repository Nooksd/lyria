import 'package:equatable/equatable.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';

class Playlist extends Equatable {
  final String id;
  final String name;
  final String imageUrl;
  final List<Music> musics;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Playlist({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.musics,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id, name, imageUrl, musics, createdAt, updatedAt];

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['imageUrl'] as String,
      musics: json['musics'].map((music) => Music.fromJson(music)).toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'musics': musics.map((music) => music.toJson()).toList(),
    };
  }
}
