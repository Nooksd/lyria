class AppUser {
  final String uid;
  final String name;
  final String role;
  final String profilePictureUrl;

  AppUser({
    required this.uid,
    required this.name,
    required this.role,
    required this.profilePictureUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'role': role,
      'profilePictureUrl': profilePictureUrl,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['id'] as String,
      name: map['name'] as String,
      role: map['role'],
      profilePictureUrl: map['profilePictureUrl'],
    );
  }
}
