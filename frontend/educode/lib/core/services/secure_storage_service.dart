import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Claves para el almacenamiento
  static const String tokenKey = 'auth_token';
  static const String userIdKey = 'user_id';
  static const String userTypeKey = 'user_type';
  static const String userNameKey = 'user_name';

  // Guardar token
  Future<void> saveToken(String token) async {
    await _storage.write(key: tokenKey, value: token);
  }

  // Obtener token
  Future<String?> getToken() async {
    return await _storage.read(key: tokenKey);
  }

  // Guardar información del usuario
  Future<void> saveUserInfo({
    required String id,
    required String type,
    required String name,
  }) async {
    await _storage.write(key: userIdKey, value: id);
    await _storage.write(key: userTypeKey, value: type);
    await _storage.write(key: userNameKey, value: name);
  }

  // Obtener información del usuario
  Future<Map<String, String?>> getUserInfo() async {
    return {
      'id': await _storage.read(key: userIdKey),
      'type': await _storage.read(key: userTypeKey),
      'name': await _storage.read(key: userNameKey),
    };
  }

  // Limpiar todos los datos (logout)
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
} 