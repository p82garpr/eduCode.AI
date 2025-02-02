import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/models/user_model.dart';

class AuthService {
  static const String _baseUrl = 'http://10.0.2.2:8000'; // Ajusta según tu API

  Future<UserModel> login(String email, String password) async {
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

      //print('Status code: ${response.statusCode}');
      //print('Response body: ${response.body}');
      // print('Request headers: ${response.request?.headers}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return UserModel.fromJson(data);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception('Error en el inicio de sesión: ${errorBody['detail'] ?? response.body}');
      }
    } catch (e) {
      //print('Error completo: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  Future<UserModel> register(String name, String lastName, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/registro'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'nombre': name,
          'apellidos': lastName,
          'email': email,
          'password': password,
          'tipo_usuario': 'Alumno',
        }),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        return UserModel.fromJson(data);
      } else {
        throw Exception('Error en el registro: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
} 