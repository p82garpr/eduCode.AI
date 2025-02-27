import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/config/app_config.dart';

import '../../domain/models/enrolled_student_model.dart';
import '../../domain/models/user_profile_model.dart';

class EnrollmentService {
  final http.Client _client;
  final String _baseUrl = AppConfig.apiBaseUrl;

  EnrollmentService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<EnrolledStudent>> getEnrolledStudents(int subjectId, String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/asignaturas/$subjectId/alumnos'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((json) => EnrolledStudent.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener los estudiantes matriculados');
      }
    } catch (e) {
      throw Exception('Error en el servicio: ${e.toString()}');
    }
  }

  Future<void> enrollInSubject(String userId, String subjectId, String accessCode, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/inscripciones/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'alumno_id': userId,
          'asignatura_id': subjectId,
          'codigo_acceso': accessCode,
        }),
      );

      if (response.statusCode != 200) {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(error['detail'] ?? 'Error al inscribirse en la asignatura');
      }
    } catch (e) {
      throw Exception('Error al inscribirse en la asignatura: ${e.toString()}');
    }
  }

  Future<void> cancelEnrollment(int subjectId, int userId, String token) async {
    try {
      final response = await _client.delete(
        Uri.parse('$_baseUrl/inscripciones/$subjectId?alumno_id=$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error al cancelar la matrícula');
      }
    } catch (e) {
      throw Exception('Error en el servicio: ${e.toString()}');
    }
  }

  Future<UserProfileModel> getUserProfile(String userId, String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/users/$userId/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return UserProfileModel.fromJson(data);
      } else {
        throw Exception('Error al obtener el perfil del usuario');
      }
    } catch (e) {
      throw Exception('Error en el servicio: ${e.toString()}');
    }
  }
} 