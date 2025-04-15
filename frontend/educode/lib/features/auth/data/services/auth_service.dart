import 'dart:convert';
import 'package:educode/core/config/app_config.dart';
import 'package:educode/core/network/http_client.dart';
import 'package:http/http.dart' as http;
import '../../domain/models/user_model.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  final http.Client _client;
  final String _baseUrl = AppConfig.apiBaseUrl;

  AuthService({http.Client? client}) 
      : _client = client ?? HttpClientFactory.createClient();

  Future<String> login(String email, String password) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/login'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'username': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['access_token'];
      } else if (response.statusCode == 401) {
        throw AuthException('Email o contraseña incorrectos');
      } else if (response.statusCode == 422) {
        throw AuthException('Por favor, ingresa un email y contraseña válidos');
      } else {
        throw AuthException('Error al iniciar sesión. Por favor, inténtalo de nuevo');
      }
    } catch (e) {
      if (e is AuthException) {
        rethrow;
      }
      throw AuthException('No pudimos conectar con el servidor. Por favor, verifica tu conexión');
    }
  }

  // Método para obtener la información del usuario
  Future<UserModel> getUserInfo(String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept-Charset': 'utf-8',
        },
      );

      if (response.statusCode == 200) {
        return UserModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      } else {
        throw AuthException('No pudimos obtener tu información. Por favor, inicia sesión nuevamente');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Error de conexión. Por favor, verifica tu internet');
    }
  }

  Future<UserModel> register(String name, String lastName, String email, String password, String userType) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/registro'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'nombre': name,
          'apellidos': lastName,
          'password': password,
          'tipo_usuario': userType, // Usar el tipo de usuario proporcionado
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return UserModel.fromJson(jsonDecode(response.body));
      } else {
        final errorData = jsonDecode(response.body);
        if (response.statusCode == 400) {
          throw AuthException('Este email ya está registrado');
        }
        throw AuthException(errorData['detail'] ?? 'No pudimos completar el registro. Por favor, inténtalo de nuevo');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Error de conexión. Por favor, verifica tu internet');
    }
  }

  Future<UserModel> updateProfile({
    required String nombre,
    required String apellidos,
    required String email,
    String? password,
    required String token,
  }) async {
    try {
      final response = await _client.put(
        Uri.parse('$_baseUrl/usuarios/update'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'nombre': nombre,
          'apellidos': apellidos,
          'email': email,
          if (password != null && password.isNotEmpty) 'password': password,
        }),
      );

      if (response.statusCode == 200) {
        return UserModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        if (response.statusCode == 400) {
          throw AuthException('Este email ya está en uso');
        }
        throw AuthException(errorData['detail'] ?? 'No pudimos actualizar tu perfil. Por favor, inténtalo de nuevo');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Error de conexión. Por favor, verifica tu internet');
    }
  }
  
  // Solicitar restablecimiento de contraseña
  Future<String> requestPasswordReset(String email) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/password-reset-request'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['message'];
      } else {
        final errorData = jsonDecode(response.body);
        if (response.statusCode == 404) {
          throw AuthException('No encontramos una cuenta con este email');
        }
        throw AuthException(errorData['detail'] ?? 'No pudimos procesar tu solicitud. Por favor, inténtalo de nuevo');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Error de conexión. Por favor, verifica tu internet');
    }
  }
  
  // Verificar token de restablecimiento
  Future<Map<String, dynamic>> verifyResetToken(String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/verify-reset-token/$token'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        if (response.statusCode == 400) {
          throw AuthException('El enlace de restablecimiento ha expirado o no es válido');
        }
        throw AuthException('No pudimos verificar el enlace. Por favor, solicita uno nuevo');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Error de conexión. Por favor, verifica tu internet');
    }
  }
  
  // Restablecer contraseña
  Future<String> resetPassword(String token, String newPassword) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/reset-password'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'token': token,
          'new_password': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['message'];
      } else {
        if (response.statusCode == 400) {
          throw AuthException('El enlace de restablecimiento ha expirado o no es válido');
        }
        throw AuthException('No pudimos cambiar tu contraseña. Por favor, inténtalo de nuevo');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Error de conexión. Por favor, verifica tu internet');
    }
  }
}