import 'package:lyria/app/modules/music/domain/entities/music.dart';

class Search {
  final String id;
  final String name;
  final String type;
  final String description;
  final String imageUrl;
  final Music? music;

  const Search({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.imageUrl,
    required this.music,
  });

  factory Search.fromJson(Map<String, dynamic> json) {
    return Search(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      description: json['description'],
      imageUrl: json['imageUrl'],
      music: json['music'] != null ? Music.fromJson(json['music']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'description': description,
      'imageUrl': imageUrl,
      'music': music?.toJson(),
    };
  }
}
