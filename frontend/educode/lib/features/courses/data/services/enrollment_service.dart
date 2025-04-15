import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/config/app_config.dart';
import '../../../../core/network/http_client.dart';

import '../../domain/models/enrolled_student_model.dart';
import '../../domain/models/user_profile_model.dart';

class EnrollmentException implements Exception {
  final String message;
  EnrollmentException(this.message);

  @override
  String toString() => message;
}

class EnrollmentService {
  final http.Client _client;
  final String _baseUrl = AppConfig.apiBaseUrl;

  EnrollmentService({http.Client? client}) 
      : _client = client ?? HttpClientFactory.createClient();

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
      } else if (response.statusCode == 404) {
        throw EnrollmentException('No se encontró la asignatura');
      } else {
        throw EnrollmentException('No pudimos obtener la lista de estudiantes');
      }
    } catch (e) {
      if (e is EnrollmentException) rethrow;
      throw EnrollmentException('Error de conexión. Por favor, verifica tu internet');
    }
  }

  Future<void> enrollInSubject(String userId, String subjectId, String accessCode, String token) async {
    try {
      final response = await _client.post(
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

      if (response.statusCode == 200) {
        return;
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        if (response.statusCode == 400) {
          if (error['detail']?.contains('código de acceso')) {
            throw EnrollmentException('El código de acceso no es válido');
          } else if (error['detail']?.contains('ya está matriculado')) {
            throw EnrollmentException('Ya estás matriculado en esta asignatura');
          }
        }
        throw EnrollmentException(error['detail'] ?? 'No pudimos completar la matrícula');
      }
    } catch (e) {
      if (e is EnrollmentException) rethrow;
      throw EnrollmentException('Error de conexión. Por favor, verifica tu internet');
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

      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      } else if (response.statusCode == 404) {
        throw EnrollmentException('No estás matriculado en esta asignatura');
      } else {
        throw EnrollmentException('No pudimos cancelar tu matrícula. Por favor, inténtalo de nuevo');
      }
    } catch (e) {
      if (e is EnrollmentException) rethrow;
      throw EnrollmentException('Error de conexión. Por favor, verifica tu internet');
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
      } else if (response.statusCode == 404) {
        throw EnrollmentException('No se encontró el perfil del usuario');
      } else {
        throw EnrollmentException('No pudimos obtener el perfil del usuario');
      }
    } catch (e) {
      if (e is EnrollmentException) rethrow;
      throw EnrollmentException('Error de conexión. Por favor, verifica tu internet');
    }
  }
} 