import 'package:equatable/equatable.dart';
import 'package:lyria/app/core/config/api_config.dart';

class FavoriteAlbum extends Equatable {
  final String id;
  final String name;
  final String artistId;
  final String artistName;
  final String albumCoverUrl;
  final String color;
  final int musicCount;
  final int totalTracks;
  final String releaseDate;

  const FavoriteAlbum({
    required this.id,
    required this.name,
    required this.artistId,
    required this.artistName,
    required this.albumCoverUrl,
    required this.color,
    required this.musicCount,
    required this.totalTracks,
    required this.releaseDate,
  });

  factory FavoriteAlbum.fromJson(Map<String, dynamic> json) {
    return FavoriteAlbum(
      id: (json['_id'] ?? json['id']) as String? ?? '',
      name: json['name'] as String? ?? '',
      artistId: json['artistId'] as String? ?? '',
      artistName: json['artistName'] as String? ?? '',
      albumCoverUrl: ApiConfig.fixImageUrl(json['albumCoverUrl'] as String?),
      color: json['color'] as String? ?? '',
      musicCount: (json['musicCount'] as num?)?.toInt() ?? 0,
      totalTracks: (json['totalTracks'] as num?)?.toInt() ?? 0,
      releaseDate: json['releaseDate'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'artistId': artistId,
      'artistName': artistName,
      'albumCoverUrl': albumCoverUrl,
      'color': color,
      'musicCount': musicCount,
      'totalTracks': totalTracks,
      'releaseDate': releaseDate,
    };
  }

  @override
  List<Object?> get props => [
        id,
        name,
        artistId,
        artistName,
        albumCoverUrl,
        color,
        musicCount,
        totalTracks,
        releaseDate,
      ];
}
