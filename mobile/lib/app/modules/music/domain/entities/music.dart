import 'package:equatable/equatable.dart';
import 'package:lyria/app/core/config/api_config.dart';
import 'package:lyria/app/modules/music/domain/entities/lyrics.dart';

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
  final String spotifyId;
  final String spotifyUrl;
  final int spotifyPopularity;
  final int spotifyDurationMs;
  final int spotifyTrackNumber;
  final int spotifyDiscNumber;
  final bool spotifyExplicit;
  final List<LyricLine>? lyrics;
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
    this.spotifyId = '',
    this.spotifyUrl = '',
    this.spotifyPopularity = 0,
    this.spotifyDurationMs = 0,
    this.spotifyTrackNumber = 0,
    this.spotifyDiscNumber = 0,
    this.spotifyExplicit = false,
    this.lyrics,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Music.fromJson(Map<String, dynamic> json) {
    return Music(
      id: json['_id'] as String,
      url: json['url'] as String,
      name: json['name'] as String,
      artistId: json['artistId'] as String? ?? '',
      artistName: json['artistName'] as String? ?? '',
      albumId: json['albumId'] as String? ?? '',
      albumName: json['albumName'] as String? ?? '',
      waveform: (json['waveform'] as List?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      genre: json['genre'] as String? ?? '',
      color: json['color'] as String? ?? '',
      coverUrl: ApiConfig.fixImageUrl(json['coverUrl'] as String?),
      spotifyId: json['spotifyId'] as String? ?? '',
      spotifyUrl: json['spotifyUrl'] as String? ?? '',
      spotifyPopularity: (json['spotifyPopularity'] as num?)?.toInt() ?? 0,
      spotifyDurationMs: (json['spotifyDurationMs'] as num?)?.toInt() ?? 0,
      spotifyTrackNumber: (json['spotifyTrackNumber'] as num?)?.toInt() ?? 0,
      spotifyDiscNumber: (json['spotifyDiscNumber'] as num?)?.toInt() ?? 0,
      spotifyExplicit: json['spotifyExplicit'] as bool? ?? false,
      lyrics: json['lyrics'] != null
          ? (json['lyrics'] as List).map((e) => LyricLine.fromJson(e)).toList()
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        url,
        name,
        artistId,
        artistName,
        albumId,
        albumName,
        waveform,
        genre,
        color,
        coverUrl,
        spotifyId,
        spotifyUrl,
        spotifyPopularity,
        spotifyDurationMs,
        spotifyTrackNumber,
        spotifyDiscNumber,
        spotifyExplicit,
        lyrics,
        createdAt,
        updatedAt
      ];

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
      'spotifyId': spotifyId,
      'spotifyUrl': spotifyUrl,
      'spotifyPopularity': spotifyPopularity,
      'spotifyDurationMs': spotifyDurationMs,
      'spotifyTrackNumber': spotifyTrackNumber,
      'spotifyDiscNumber': spotifyDiscNumber,
      'spotifyExplicit': spotifyExplicit,
      'lyrics': lyrics?.map((l) => l.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
