import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import 'transport_api_client.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const _keyToken = 'auth_token';
  static const _keyUserId = 'user_id';
  static const _keyUserName = 'user_name';
  static const _keyUserEmail = 'user_email';
  static const _keyUserPhone = 'user_phone';
  static const _keyUserRole = 'user_role';
  static const _keyUserAvatar = 'user_avatar';

  UserModel? _currentUser;
  String? _token;
  bool _guest = false;

  UserModel? get currentUser => _currentUser;
  String? get token => _token;
  bool get isGuest => _guest;
  bool get isAuthenticated => _token != null && !_guest;

  UserModel get demoUser => const UserModel(
        name: 'Sabrina Aryan',
        email: 'test@example.com',
        phone: '+216 94 064 70',
        role: 'client',
        avatarUrl:
            'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=512&q=80',
      );

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken);
    if (token == null || token.isEmpty) return;
    _token = token;
    _guest = false;
    TransportApiClient.instance.setToken(token);
    _currentUser = UserModel(
      id: prefs.getString(_keyUserId) ?? '',
      name: prefs.getString(_keyUserName) ?? '',
      email: prefs.getString(_keyUserEmail) ?? '',
      phone: prefs.getString(_keyUserPhone) ?? '',
      role: prefs.getString(_keyUserRole) ?? 'client',
      avatarUrl: prefs.getString(_keyUserAvatar),
    );
  }

  Future<UserModel> login({
    required String identifier,
    required String password,
  }) async {
    final response = await TransportApiClient.instance.post('/auth/login', {
      'email': identifier.trim(),
      'password': password.trim(),
    });
    _token = response['access_token']?.toString();
    _guest = false;
    TransportApiClient.instance.setToken(_token);
    final user =
        _userFromAuthResponse(response, fallbackEmail: identifier.trim());
    _currentUser = user;
    await _saveToStorage(user, _token);
    return user;
  }

  Future<UserModel> signup({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final response = await TransportApiClient.instance.post('/auth/signup', {
      'full_name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'password': password.trim(),
    });
    _token = response['access_token']?.toString();
    _guest = false;
    TransportApiClient.instance.setToken(_token);
    final user = _userFromAuthResponse(response, fallbackEmail: email.trim());
    _currentUser = user;
    await _saveToStorage(user, _token);
    return user;
  }

  UserModel continueAsGuest() {
    _token = null;
    _guest = true;
    TransportApiClient.instance.setToken(null);
    const user = UserModel(
      id: 'guest',
      name: 'Guest',
      email: '',
      phone: '',
      role: 'guest',
    );
    _currentUser = user;
    return user;
  }

  Future<UserModel> updateProfile({
    required String name,
    required String email,
    required String phone,
  }) async {
    final response = await TransportApiClient.instance.put('/auth/me', {
      'full_name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
    });
    final userPayload =
        (response['user'] as Map?)?.cast<String, dynamic>() ?? {};
    final updated = (_currentUser ?? demoUser).copyWith(
      name: userPayload['full_name']?.toString() ?? name,
      email: userPayload['email']?.toString() ?? email,
      phone: userPayload['phone']?.toString() ?? phone,
      avatarUrl: userPayload['avatar_url']?.toString(),
    );
    _currentUser = updated;
    await _saveToStorage(updated, _token);
    return updated;
  }

  Future<UserModel> refreshProfile() async {
    final response = await TransportApiClient.instance.get('/auth/me');
    final userPayload =
        (response['user'] as Map?)?.cast<String, dynamic>() ?? {};
    final updated = (_currentUser ?? demoUser).copyWith(
      id: userPayload['id']?.toString() ?? _currentUser?.id ?? '',
      name: userPayload['full_name']?.toString() ??
          userPayload['name']?.toString() ??
          _currentUser?.name ??
          '',
      email: userPayload['email']?.toString() ?? _currentUser?.email ?? '',
      phone: userPayload['phone']?.toString() ?? _currentUser?.phone ?? '',
      role: userPayload['role']?.toString() ?? _currentUser?.role ?? 'client',
      avatarUrl: userPayload['avatar_url']?.toString(),
    );
    _currentUser = updated;
    await _saveToStorage(updated, _token);
    return updated;
  }

  Future<UserModel> uploadAvatar(XFile file) async {
    final bytes = await file.readAsBytes();
    final response = await TransportApiClient.instance.postMultipart(
      '/auth/me/avatar',
      fileField: 'file',
      bytes: bytes,
      filename: file.name.isEmpty ? 'avatar.jpg' : file.name,
    );
    final userPayload =
        (response['user'] as Map?)?.cast<String, dynamic>() ?? {};
    final updated = (_currentUser ?? demoUser).copyWith(
      id: userPayload['id']?.toString() ?? _currentUser?.id ?? '',
      name: userPayload['full_name']?.toString() ??
          userPayload['name']?.toString() ??
          _currentUser?.name ??
          '',
      email: userPayload['email']?.toString() ?? _currentUser?.email ?? '',
      phone: userPayload['phone']?.toString() ?? _currentUser?.phone ?? '',
      role: userPayload['role']?.toString() ?? _currentUser?.role ?? 'client',
      avatarUrl: userPayload['avatar_url']?.toString(),
    );
    _currentUser = updated;
    await _saveToStorage(updated, _token);
    return updated;
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    _guest = false;
    TransportApiClient.instance.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserPhone);
    await prefs.remove(_keyUserRole);
    await prefs.remove(_keyUserAvatar);
  }

  UserModel _userFromAuthResponse(Map<String, dynamic> response,
      {required String fallbackEmail}) {
    final userPayload =
        (response['user'] as Map?)?.cast<String, dynamic>() ?? {};
    return UserModel(
      id: userPayload['id']?.toString() ?? '',
      name: userPayload['name']?.toString() ?? '',
      email: userPayload['email']?.toString() ?? fallbackEmail,
      phone: userPayload['phone']?.toString() ?? '',
      role: response['role']?.toString() ??
          userPayload['role']?.toString() ??
          'client',
      avatarUrl: userPayload['avatar_url']?.toString(),
    );
  }

  Future<void> _saveToStorage(UserModel user, String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token != null) await prefs.setString(_keyToken, token);
    await prefs.setString(_keyUserId, user.id);
    await prefs.setString(_keyUserName, user.name);
    await prefs.setString(_keyUserEmail, user.email);
    await prefs.setString(_keyUserPhone, user.phone);
    await prefs.setString(_keyUserRole, user.role);
    if (user.avatarUrl != null) {
      await prefs.setString(_keyUserAvatar, user.avatarUrl!);
    } else {
      await prefs.remove(_keyUserAvatar);
    }
  }
}
