class AppUser {
  final String uid;
  final String avatarUrl;
  final String name;
  final String userType;
  final String email;
  final List<String> favorites;

  AppUser({
    required this.uid,
    required this.name,
    required this.userType,
    required this.avatarUrl,
    required this.email,
    required this.favorites,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'favorites': favorites,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['id'] as String,
      name: map['name'] as String,
      userType: map['userType'] ?? "USER",
      avatarUrl: map['avatarUrl'],
      email: map['email'],
      favorites: map['favorites'] ?? [],
    );
  }
}
