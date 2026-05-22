import 'package:equatable/equatable.dart';
import 'package:lyria/app/core/config/api_config.dart';

class FavoriteArtist extends Equatable {
  final String id;
  final String name;
  final String avatarUrl;
  final String bannerUrl;
  final String bio;
  final String color;
  final List<String> genres;
  final int musicCount;
  final int albumCount;
  final int spotifyPopularity;
  final int spotifyFollowers;

  const FavoriteArtist({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.bannerUrl,
    required this.bio,
    required this.color,
    required this.genres,
    required this.musicCount,
    required this.albumCount,
    required this.spotifyPopularity,
    required this.spotifyFollowers,
  });

  factory FavoriteArtist.fromJson(Map<String, dynamic> json) {
    return FavoriteArtist(
      id: (json['_id'] ?? json['id']) as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarUrl: ApiConfig.fixImageUrl(json['avatarUrl'] as String?),
      bannerUrl: ApiConfig.fixImageUrl(json['bannerUrl'] as String?),
      bio: json['bio'] as String? ?? '',
      color: json['color'] as String? ?? '',
      genres:
          (json['genres'] as List?)?.map((e) => e.toString()).toList() ?? [],
      musicCount: (json['musicCount'] as num?)?.toInt() ?? 0,
      albumCount: (json['albumCount'] as num?)?.toInt() ?? 0,
      spotifyPopularity: (json['spotifyPopularity'] as num?)?.toInt() ?? 0,
      spotifyFollowers: (json['spotifyFollowers'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'avatarUrl': avatarUrl,
      'bannerUrl': bannerUrl,
      'bio': bio,
      'color': color,
      'genres': genres,
      'musicCount': musicCount,
      'albumCount': albumCount,
      'spotifyPopularity': spotifyPopularity,
      'spotifyFollowers': spotifyFollowers,
    };
  }

  @override
  List<Object?> get props => [
        id,
        name,
        avatarUrl,
        bannerUrl,
        bio,
        color,
        genres,
        musicCount,
        albumCount,
        spotifyPopularity,
        spotifyFollowers,
      ];
}
