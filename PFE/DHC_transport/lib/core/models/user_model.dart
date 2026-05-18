class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? avatarUrl;
  final String role;

  const UserModel({
    this.id = '',
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.avatarUrl,
  });

  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    String? role,
    String? id,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  bool get isGuest => role == 'guest';

  String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    final letters = parts.map((part) => part.substring(0, 1)).take(2).toList();
    if (letters.isEmpty) return 'DH';
    return letters.join().toUpperCase();
  }
}
