import '../models/user_model.dart';

enum AuthRole { client, admin, driver }

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  UserModel? _currentUser;

  UserModel get demoUser => const UserModel(
        name: 'Sabrina Aryan',
        email: 'test@example.com',
        phone: '+216 94 064 70',
        role: 'client',
        avatarUrl:
            'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=512&q=80',
      );

  UserModel? get currentUser => _currentUser;

  Future<UserModel> login({
    required String identifier,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final role = _resolveRole(identifier, password);
    if (role == null) {
      throw StateError('Invalid credentials');
    }
    final user = switch (role) {
      AuthRole.admin => const UserModel(
          name: 'Admin',
          email: 'admin',
          phone: 'admin',
          role: 'admin',
          avatarUrl:
              'https://images.unsplash.com/photo-1560250097-0b93528c311a?auto=format&fit=crop&w=512&q=80',
        ),
      AuthRole.driver => const UserModel(
          name: 'Driver',
          email: 'driver',
          phone: 'driver',
          role: 'driver',
          avatarUrl:
              'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=512&q=80',
        ),
      AuthRole.client => demoUser.copyWith(
          email: demoUser.email,
          phone: demoUser.phone,
          role: 'client',
        ),
    };
    _currentUser = user;
    return user;
  }

  Future<UserModel> signup({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    final user = UserModel(
      name: fullName,
      email: email,
      phone: phone,
      role: 'client',
      avatarUrl: demoUser.avatarUrl,
    );
    _currentUser = user;
    return user;
  }

  Future<UserModel> updateProfile({
    required String name,
    required String email,
    required String phone,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final user = (_currentUser ?? demoUser).copyWith(
      name: name,
      email: email,
      phone: phone,
    );
    _currentUser = user;
    return user;
  }

  Future<void> logout() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _currentUser = null;
  }

  AuthRole? _resolveRole(String identifier, String password) {
    final id = identifier.trim().toLowerCase();
    final pass = password.trim().toLowerCase();

    if (id == 'admin' && pass == 'admin') return AuthRole.admin;
    if (id == 'driver' && pass == 'driver') return AuthRole.driver;
    if ((id == 'test' || id == 'test@example.com') && pass == 'test') {
      return AuthRole.client;
    }
    return null;
  }
}
