import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/models/user_model.dart';

class AuthService {
  static const String _baseUrl = 'http://10.0.2.2:8000'; // Ajusta según tu API

  Future<String> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/login'),

        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'username': email,
          'password': password,
        },
      );

      //print('Status code: ${response.statusCode}'); // Para debug
      //print('Response body: ${response.body}'); // Para debug

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['access_token'];
      } else {
        throw Exception('Credenciales inválidas');
      }
    } catch (e) {
      //print('Error en login: $e'); // Para debug
      throw Exception('Error en el login: $e');
    }
  }

  // Método para obtener la información del usuario
  Future<UserModel> getUserInfo(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/me'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return UserModel.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Error al obtener información del usuario');
      }
    } catch (e) {
      throw Exception('Error al obtener información del usuario: $e');
    }
  }

  Future<UserModel> register(String name, String lastName, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/registro'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'nombre': name,
          'apellidos': lastName,
          'password': password,
          'tipo_usuario': 'Alumno', // Por defecto registramos como alumno
        }),
      );
    
      //print('Status code: ${response.statusCode}'); // Para debug
      //print('Response body: ${response.body}'); // Para debug


      if (response.statusCode == 201 || response.statusCode == 200) {
        return UserModel.fromJson(jsonDecode(response.body));
      } else {
        throw Exception(jsonDecode(response.body)['detail'] ?? 'Error en el registro');
      }
    } catch (e) { 
      final decodedError = utf8.decode(e.toString().codeUnits);
      throw Exception(': $decodedError');
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
      final response = await http.put(
        Uri.parse('$_baseUrl/api/v1/usuarios/update'),
        headers: {
          'Content-Type': 'application/json',
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
        return UserModel.fromJson(jsonDecode(response.body));
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Error al actualizar el perfil');
      }
    } catch (e) {
      throw Exception('Error al actualizar el perfil: ${e.toString()}');
    }
  }
}