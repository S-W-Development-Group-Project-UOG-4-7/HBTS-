class AppUser {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? profileImage;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.profileImage,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: (json['id'] ?? json['_id'] ?? json['user_id'] ?? '').toString(),
      name: (json['name'] ?? json['fullName'] ?? 'User').toString(),
      email: (json['email'] ?? '').toString(),
      phone: json['phone']?.toString(),
      profileImage: json['profileImage']?.toString(),
    );
  }
}
