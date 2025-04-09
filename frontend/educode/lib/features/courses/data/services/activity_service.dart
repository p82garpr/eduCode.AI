import 'dart:convert';
import 'package:educode/features/courses/domain/models/activity_model.dart';
import 'package:http/http.dart' as http;
import '../../../../core/config/app_config.dart';
import '../../../../core/network/http_client.dart';

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
      } else {
        throw Exception('Error al obtener las actividades');
      }
    } catch (e) {
      throw Exception('Error en el servicio: ${e.toString()}');
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
      } else {
        throw Exception('Error al cargar las actividades del curso');
      }
    } catch (e) {
      throw Exception('Error de conexión: ${e.toString()}');
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
      } else {
        throw Exception('Error al crear la actividad');
      }
    } catch (e) {
      throw Exception('Error de conexión: ${e.toString()}');
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
      } else {
        throw Exception('Error al actualizar la actividad');
      }
    } catch (e) {
      throw Exception('Error al actualizar la actividad: ${e.toString()}');
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

      if (response.statusCode != 204) {
        throw Exception('Error al eliminar la actividad');
      }
    } catch (e) {
      throw Exception('Error en el servicio: ${e.toString()}');
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
      } else {
        throw Exception('Error al obtener la actividad: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al obtener la actividad: ${e.toString()}');
    }
  }


  Future<String> downloadActivityCsv(int activityId, String token) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/entregas/actividad/$activityId/export-csv'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Error al descargar el CSV');
    }

    return response.body;
  }
} 