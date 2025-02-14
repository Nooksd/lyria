import 'package:equatable/equatable.dart';

class Music extends Equatable {
  final String id;
  final String url;
  final String name;
  final String artistId;
  final String artistName;
  final String albumId;
  final String albumName;
  final List<double> waveform;
  final String genre;
  final String color;
  final String coverUrl;
  final String? lyrics;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Music({
    required this.id,
    required this.url,
    required this.name,
    required this.artistId,
    required this.artistName,
    required this.albumId,
    required this.albumName,
    required this.waveform,
    required this.genre,
    required this.color,
    required this.coverUrl,
    this.lyrics,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Music.fromJson(Map<String, dynamic> json) {
    return Music(
      id: json['_id'] as String,
      url: json['url'] as String,
      name: json['name'] as String,
      artistId: json['artistId'] as String,
      artistName: json['artistName'] as String,
      albumId: json['albumId'] as String,
      albumName: json['albumName'] as String,
      waveform: (json['waveform'] as List).map((e) => (e as num).toDouble()).toList(),
      genre: json['genre'] as String,
      color: json['color'] as String,
      coverUrl: json['coverUrl'] as String,
      lyrics: json['lyrics'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  List<Object?> get props => [id, url, name, artistId, artistName, albumId, albumName, waveform, genre, color, coverUrl, lyrics, createdAt, updatedAt];

  String get audioUrl => url;

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'url': url,
      'name': name,
      'artistId': artistId,
      'artistName': artistName,
      'albumId': albumId,
      'albumName': albumName,
      'waveform': waveform,
      'genre': genre,
      'color': color,
      'coverUrl': coverUrl,
      'lyrics': lyrics,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
