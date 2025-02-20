import 'dart:convert';
import 'package:educode/features/courses/domain/models/activity_model.dart';
import 'package:http/http.dart' as http;

import '../../domain/models/subject_model.dart';

class SubjectsService {
  final http.Client _client;
  final String _baseUrl = 'http://10.0.2.2:8000/api/v1';

  SubjectsService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<Subject>> getCoursesByUser(String userId, String role, String token) async {
    try {
      final endpoint = role == 'Profesor' 
          ? '/inscripciones/mis-asignaturas-impartidas/'
          : '/inscripciones/mis-asignaturas';

      final response = await http.get(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((json) => Subject.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener los cursos: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
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
      );

      if (response.statusCode == 201) {
        return Subject.fromJson(json.decode(response.body));
      } else {
        throw Exception('Error al crear la asignatura');
      }
    } catch (e) {
      throw Exception('Error en el servicio: ${e.toString()}');
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
      } else {
        throw Exception('Error al actualizar la asignatura');
      }
    } catch (e) {
      throw Exception('Error en el servicio: ${e.toString()}');
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
        return Subject.fromJson(json.decode(response.body));
      } else {
        throw Exception('Error al obtener los detalles de la asignatura');
      }
    } catch (e) {
      throw Exception('Error en el servicio: ${e.toString()}');
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
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Subject.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener las asignaturas disponibles');
      }
    } catch (e) {
      throw Exception('Error en el servicio: ${e.toString()}');
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
      } else {
        throw Exception('Error al descargar el CSV de la asignatura');
      }
    } catch (e) {
      throw Exception('Error en el servicio: ${e.toString()}');
    }
  }

  Future<List<ActivityModel>> getCourseActivities(int courseId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/actividades/asignatura/$courseId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(utf8.decode(response.bodyBytes));
        return jsonList.map((json) => ActivityModel.fromJson(json)).toList();
      } else {
        throw Exception('Error al cargar las actividades del curso');
      }
    } catch (e) {
      throw Exception('Error de conexión: ${e.toString()}');
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

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error al eliminar la asignatura');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}