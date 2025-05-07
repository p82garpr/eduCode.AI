import 'dart:convert';
import 'package:educode/features/courses/domain/models/activity_model.dart';
import 'package:http/http.dart' as http;
import '../../../../core/config/app_config.dart';
import '../../../../core/network/http_client.dart';

import '../../domain/models/subject_model.dart';

class SubjectException implements Exception {
  final String message;
  SubjectException(this.message);

  @override
  String toString() => message;
}

class SubjectsService {
  final http.Client _client;
  final String _baseUrl = AppConfig.apiBaseUrl;

  SubjectsService({http.Client? client}) 
      : _client = client ?? HttpClientFactory.createClient();

  Future<List<Subject>> getCoursesByUser(String userId, String role, String token) async {
    try {
      final endpoint = role == 'Profesor' 
          ? '/inscripciones/mis-asignaturas-impartidas/'
          : '/inscripciones/mis-asignaturas';

      final response = await _client.get(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((json) => Subject.fromJson(json)).toList();
      } else if (response.statusCode == 404) {
        throw SubjectException('No se encontraron asignaturas asociadas a tu cuenta');
      } else if (response.statusCode == 403) {
        throw SubjectException('No tienes permisos para ver estas asignaturas');
      } else {
        throw SubjectException('No pudimos obtener tus asignaturas');
      }
    } catch (e) {
      if (e is SubjectException) rethrow;
      throw SubjectException('Error de conexión. Por favor, verifica tu internet');
    }
  }

  Future<Subject> createSubject(Map<String, String> data, String token) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/asignaturas/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(data),
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw SubjectException('Tiempo de espera agotado. Por favor, inténtalo de nuevo.');
      });

      // Imprimir para depuración
      print('Respuesta createSubject: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return Subject.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      } else if (response.statusCode == 403) {
        throw SubjectException('No tienes permisos para crear asignaturas');
      } else if (response.statusCode == 400) {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw SubjectException(error['detail'] ?? 'Los datos de la asignatura no son válidos');
      } else {
        throw SubjectException('No pudimos crear la asignatura. Código: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en createSubject service: $e');
      if (e is SubjectException) rethrow;
      throw SubjectException('Error de conexión. Por favor, verifica tu internet');
    }
  }

  Future<Subject> updateSubject(int subjectId, Map<String, String> data, String token) async {
    try {
      final response = await _client.put(
        Uri.parse('$_baseUrl/asignaturas/$subjectId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        return Subject.fromJson(json.decode(response.body));
      } else if (response.statusCode == 404) {
        throw SubjectException('No se encontró la asignatura que intentas modificar');
      } else if (response.statusCode == 403) {
        throw SubjectException('No tienes permisos para modificar esta asignatura');
      } else if (response.statusCode == 400) {
        final error = json.decode(response.body);
        throw SubjectException(error['detail'] ?? 'Los datos de actualización no son válidos');
      } else {
        throw SubjectException('No pudimos actualizar la asignatura');
      }
    } catch (e) {
      if (e is SubjectException) rethrow;
      throw SubjectException('Error de conexión. Por favor, verifica tu internet');
    }
  }

  Future<Subject> getSubjectDetail(int subjectId, String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/asignaturas/$subjectId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return Subject.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      } else if (response.statusCode == 404) {
        throw SubjectException('No se encontró la asignatura solicitada');
      } else if (response.statusCode == 403) {
        throw SubjectException('No tienes permisos para ver esta asignatura');
      } else {
        throw SubjectException('No pudimos obtener los detalles de la asignatura');
      }
    } catch (e) {
      if (e is SubjectException) rethrow;
      throw SubjectException('Error de conexión. Por favor, verifica tu internet');
    }
  }

  Future<List<Subject>> getAvailableSubjects(String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/asignaturas/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((json) => Subject.fromJson(json)).toList();
      } else if (response.statusCode == 403) {
        throw SubjectException('No tienes permisos para ver las asignaturas disponibles');
      } else {
        throw SubjectException('No pudimos obtener las asignaturas disponibles');
      }
    } catch (e) {
      if (e is SubjectException) rethrow;
      throw SubjectException('Error de conexión. Por favor, verifica tu internet');
    }
  }

  Future<String> downloadSubjectCsv(int subjectId, String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/asignaturas/$subjectId/export-csv'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return response.body;
      } else if (response.statusCode == 404) {
        throw SubjectException('No se encontró la asignatura para exportar');
      } else if (response.statusCode == 403) {
        throw SubjectException('No tienes permisos para exportar esta asignatura');
      } else {
        throw SubjectException('No pudimos descargar el archivo CSV de la asignatura');
      }
    } catch (e) {
      if (e is SubjectException) rethrow;
      throw SubjectException('Error de conexión. Por favor, verifica tu internet');
    }
  }

  Future<List<ActivityModel>> getCourseActivities(int courseId, String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/actividades/asignatura/$courseId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(utf8.decode(response.bodyBytes));
        return jsonList.map((json) => ActivityModel.fromJson(json)).toList();
      } else if (response.statusCode == 404) {
        throw SubjectException('No se encontraron actividades para esta asignatura');
      } else if (response.statusCode == 403) {
        throw SubjectException('No tienes permisos para ver las actividades de esta asignatura');
      } else {
        throw SubjectException('No pudimos cargar las actividades del curso');
      }
    } catch (e) {
      if (e is SubjectException) rethrow;
      throw SubjectException('Error de conexión. Por favor, verifica tu internet');
    }
  }

  Future<void> deleteSubject(int subjectId, String token) async {
    try {
      final response = await _client.delete(
        Uri.parse('$_baseUrl/asignaturas/$subjectId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      } else if (response.statusCode == 404) {
        throw SubjectException('No se encontró la asignatura que intentas eliminar');
      } else if (response.statusCode == 403) {
        throw SubjectException('No tienes permisos para eliminar esta asignatura');
      } else {
        throw SubjectException('No pudimos eliminar la asignatura');
      }
    } catch (e) {
      if (e is SubjectException) rethrow;
      throw SubjectException('Error de conexión. Por favor, verifica tu internet');
    }
  }
}