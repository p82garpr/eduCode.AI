import 'dart:convert';
import 'package:educode/features/courses/domain/models/activity_model.dart';
import 'package:http/http.dart' as http;
import '../../../../core/config/app_config.dart';
import '../../../../core/network/http_client.dart';

class ActivityException implements Exception {
  final String message;
  ActivityException(this.message);

  @override
  String toString() => message;
}

class ActivityService {
  final http.Client _client;
  final String _baseUrl = AppConfig.apiBaseUrl;

  ActivityService({http.Client? client}) 
      : _client = client ?? HttpClientFactory.createClient();

  Future<List<ActivityModel>> getActivities(int subjectId, String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/subjects/$subjectId/activities'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((json) => ActivityModel.fromJson(json)).toList();
      } else if (response.statusCode == 404) {
        throw ActivityException('No se encontraron actividades para esta asignatura');
      } else if (response.statusCode == 403) {
        throw ActivityException('No tienes permisos para ver las actividades');
      } else {
        throw ActivityException('No pudimos obtener las actividades');
      }
    } catch (e) {
      if (e is ActivityException) rethrow;
      throw ActivityException('Error de conexión. Por favor, verifica tu internet');
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
        throw ActivityException('No se encontraron actividades para este curso');
      } else if (response.statusCode == 403) {
        throw ActivityException('No tienes permisos para ver las actividades de este curso');
      } else {
        throw ActivityException('No pudimos cargar las actividades del curso');
      }
    } catch (e) {
      if (e is ActivityException) rethrow;
      throw ActivityException('Error de conexión. Por favor, verifica tu internet');
    }
  }

  Future<ActivityModel> createActivity(int subjectId, Map<String, dynamic> data, String token) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/actividades/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          ...data,
          'asignatura_id': subjectId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ActivityModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      } else if (response.statusCode == 403) {
        throw ActivityException('No tienes permisos para crear actividades en esta asignatura');
      } else if (response.statusCode == 400) {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw ActivityException(error['detail'] ?? 'Los datos de la actividad no son válidos');
      } else {
        throw ActivityException('No pudimos crear la actividad');
      }
    } catch (e) {
      if (e is ActivityException) rethrow;
      throw ActivityException('Error de conexión. Por favor, verifica tu internet');
    }
  }

  Future<ActivityModel> updateActivity(int activityId, Map<String, dynamic> data, String token) async {
    try {
      final response = await _client.put(
        Uri.parse('$_baseUrl/actividades/$activityId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return ActivityModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      } else if (response.statusCode == 404) {
        throw ActivityException('No se encontró la actividad que intentas modificar');
      } else if (response.statusCode == 403) {
        throw ActivityException('No tienes permisos para modificar esta actividad');
      } else if (response.statusCode == 400) {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw ActivityException(error['detail'] ?? 'Los datos de actualización no son válidos');
      } else {
        throw ActivityException('No pudimos actualizar la actividad');
      }
    } catch (e) {
      if (e is ActivityException) rethrow;
      throw ActivityException('Error de conexión. Por favor, verifica tu internet');
    }
  }

  Future<void> deleteActivity(int activityId, String token) async {
    try {
      final response = await _client.delete(
        Uri.parse('$_baseUrl/actividades/$activityId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 204) {
        return;
      } else if (response.statusCode == 404) {
        throw ActivityException('No se encontró la actividad que intentas eliminar');
      } else if (response.statusCode == 403) {
        throw ActivityException('No tienes permisos para eliminar esta actividad');
      } else {
        throw ActivityException('No pudimos eliminar la actividad');
      }
    } catch (e) {
      if (e is ActivityException) rethrow;
      throw ActivityException('Error de conexión. Por favor, verifica tu internet');
    }
  }

  Future<ActivityModel> getActivity(int activityId, String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/actividades/$activityId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return ActivityModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      } else if (response.statusCode == 404) {
        throw ActivityException('No se encontró la actividad solicitada');
      } else if (response.statusCode == 403) {
        throw ActivityException('No tienes permisos para ver esta actividad');
      } else {
        throw ActivityException('No pudimos obtener la información de la actividad');
      }
    } catch (e) {
      if (e is ActivityException) rethrow;
      throw ActivityException('Error de conexión. Por favor, verifica tu internet');
    }
  }

  Future<String> downloadActivityCsv(int activityId, String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/entregas/actividad/$activityId/export-csv'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return response.body;
      } else if (response.statusCode == 404) {
        throw ActivityException('No se encontró la actividad para exportar');
      } else if (response.statusCode == 403) {
        throw ActivityException('No tienes permisos para exportar esta actividad');
      } else {
        throw ActivityException('No pudimos descargar el archivo CSV de la actividad');
      }
    } catch (e) {
      if (e is ActivityException) rethrow;
      throw ActivityException('Error de conexión. Por favor, verifica tu internet');
    }
  }
} 