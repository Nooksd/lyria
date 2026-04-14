import 'package:equatable/equatable.dart';
import 'package:lyria/app/modules/music/domain/entities/music.dart';

class Playlist extends Equatable {
  final String id;
  final String name;
  final String playlistCoverUrl;
  final List<Music> musics;
  final int? musicCount;
  final DateTime? updatedAt;

  const Playlist({
    required this.id,
    required this.name,
    required this.playlistCoverUrl,
    required this.musics,
    this.musicCount,
    this.updatedAt,
  });

  int get totalMusics => musicCount ?? musics.length;

  bool get isLocal => id.startsWith('local_');

  @override
  List<Object?> get props =>
      [id, name, playlistCoverUrl, musics, musicCount, updatedAt];

  Playlist copyWith({
    String? id,
    String? name,
    String? playlistCoverUrl,
    List<Music>? musics,
    int? musicCount,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      playlistCoverUrl: playlistCoverUrl ?? this.playlistCoverUrl,
      musics: musics ?? this.musics,
      musicCount: musicCount ?? this.musicCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    List<Music> parsedMusics = [];
    if (json['musics'] != null) {
      for (final music in json['musics'] as List<dynamic>) {
        if (music is Map<String, dynamic>) {
          try {
            parsedMusics.add(Music.fromJson(music));
          } catch (_) {}
        }
      }
    }

    DateTime? parsedUpdatedAt;
    if (json['updatedAt'] != null) {
      try {
        parsedUpdatedAt = DateTime.parse(json['updatedAt'] as String);
      } catch (_) {}
    }

    return Playlist(
      id: (json['_id'] ?? json['id']) as String,
      name: json['name'] as String,
      playlistCoverUrl: json['playlistCoverUrl'] as String,
      musics: parsedMusics,
      musicCount: json['musicCount'] as int?,
      updatedAt: parsedUpdatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'playlistCoverUrl': playlistCoverUrl,
      'musics': musics.map((music) => music.toJson()).toList(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }
}
