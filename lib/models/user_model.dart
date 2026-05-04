class UserModel {
  final String name;
  final String email;
  final String phone;
  final String? avatarUrl;
  final String role;

  const UserModel({
    required this.name,
    required this.email,
    required this.phone,
    this.role = 'client',
    this.avatarUrl,
  });

  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    String? role,
  }) {
    return UserModel(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts
        .map((part) => part.isEmpty ? '' : part.substring(0, 1))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();
    if (letters.isEmpty) return 'CT';
    return letters.join().toUpperCase();
  }
}
