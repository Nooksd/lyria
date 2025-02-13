import 'package:equatable/equatable.dart';

class Music extends Equatable {
  final String id;
  final String url;
  final String name;
  final String artistId;
  final String albumId;
  final String genre;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Music({
    required this.id,
    required this.url,
    required this.name,
    required this.artistId,
    required this.albumId,
    required this.genre,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Music.fromJson(Map<String, dynamic> json) {
    return Music(
      id: json['id'] as String,
      url: json['url'] as String,
      name: json['name'] as String,
      artistId: json['artistId'] as String,
      albumId: json['albumId'] as String,
      genre: json['genre'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  List<Object?> get props => [id, url, name, artistId, albumId, genre, createdAt, updatedAt];

  String get audioUrl => url;
}
