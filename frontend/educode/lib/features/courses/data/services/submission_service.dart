import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/config/app_config.dart';
import '../../../../core/network/http_client.dart';

import '../../domain/models/submission_model.dart';
import 'package:http_parser/http_parser.dart';

class SubmissionException implements Exception {
  final String message;
  SubmissionException(this.message);

  @override
  String toString() => message;
}

class SubmissionService {
  final http.Client _client;
  final String _baseUrl = AppConfig.apiBaseUrl;

  SubmissionService({http.Client? client}) : _client = client ?? HttpClientFactory.createClient();

 Future<List<Submission>> getActivitySubmissions(int activityId, String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/entregas/actividad/$activityId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(utf8.decode(response.bodyBytes));  
        return jsonList.map((json) => Submission.fromJson(json)).toList();
      } else if (response.statusCode == 404) {
        throw SubmissionException('No se encontraron entregas para esta actividad');
      } else {
        throw SubmissionException('No pudimos obtener las entregas de la actividad');
      }
    } catch (e) {
      if (e is SubmissionException) rethrow;
      throw SubmissionException('Error de conexión. Por favor, verifica tu internet');
    }
  }

  Future<void> gradeSubmission(int submissionId, double grade, String token) async {
    try {
      final response = await _client.patch(
        Uri.parse('$_baseUrl/entregas/$submissionId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'calificacion': grade,
          'comentarios': "Evaluado manualmente por el profesor",
        }),
      );

      if (response.statusCode == 200) {
        return;
      } else if (response.statusCode == 404) {
        throw SubmissionException('No se encontró la entrega especificada');
      } else if (response.statusCode == 403) {
        throw SubmissionException('No tienes permisos para calificar esta entrega');
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw SubmissionException(error['detail'] ?? 'No pudimos calificar la entrega');
      }
    } catch (e) {
      if (e is SubmissionException) rethrow;
      throw SubmissionException('Error de conexión. Por favor, verifica tu internet');
    }
  }

 Future<Submission?> getStudentSubmission(int entregaId, String token) async {
      try {
        final response = await _client.get(
          Uri.parse('$_baseUrl/entregas/$entregaId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          final decodedData = json.decode(utf8.decode(response.bodyBytes));
          return Submission.fromJson(decodedData);
        } else if (response.statusCode == 404) {
          return null;
        } else if (response.statusCode == 403) {
          throw SubmissionException('No tienes permisos para ver esta entrega');
        } else {
          throw SubmissionException('No pudimos obtener la información de la entrega');
        }
      } catch (e) {
        if (e is SubmissionException) rethrow;
        throw SubmissionException('Error de conexión. Por favor, verifica tu internet');
      } 
    }

  Future<Submission?> getStudentSubmission2(int alumnoId, int actividadId, String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/entregas/alumno/$alumnoId/actividad/$actividadId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decodedData = json.decode(utf8.decode(response.bodyBytes));
        return Submission.fromJson(decodedData);
      } else if (response.statusCode == 404) {
        return null;
      } else if (response.statusCode == 403) {
        throw SubmissionException('No tienes permisos para ver esta entrega');
      } else {
        throw SubmissionException('No pudimos obtener la información de la entrega');
      }
    } catch (e) {
      if (e is SubmissionException) rethrow;
      throw SubmissionException('Error de conexión. Por favor, verifica tu internet');
    }
  }

  Future<Submission> submitActivity(int activityId, String solution, String token, {File? image}) async {
    try {
      // Usar nuestro cliente HTTP personalizado
      final httpClient = HttpClientFactory.createClient();
      
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/entregas/$activityId/entrega'),
      );

      // Añadir headers
      request.headers['Authorization'] = 'Bearer $token';

      // Añadir el texto OCR como campo
      request.fields['textoOcr'] = solution;

      // Si hay imagen, añadirla al request
      if (image != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'imagen',
            image.path,
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      }

      final streamedResponse = await httpClient.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Submission.fromJson(json.decode(response.body));
      } else if (response.statusCode == 403) {
        throw SubmissionException('No tienes permisos para realizar esta entrega');
      } else if (response.statusCode == 400) {
        final error = json.decode(response.body);
        throw SubmissionException(error['detail'] ?? 'La entrega no cumple con los requisitos necesarios');
      } else {
        throw SubmissionException('No pudimos procesar tu entrega. Por favor, inténtalo de nuevo');
      }
    } catch (e) {
      if (e is SubmissionException) rethrow;
      throw SubmissionException('Error de conexión. Por favor, verifica tu internet');
    }
  }

  Future<Submission> getSubmissionDetails(int submissionId, String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/entregas/$submissionId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
  
      if (response.statusCode == 200) {
        final submissionData = jsonDecode(utf8.decode(response.bodyBytes));
        
        final studentResponse = await _client.get(
          Uri.parse('$_baseUrl/${submissionData['alumno_id']}'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (studentResponse.statusCode == 200) {
          final studentData = jsonDecode(utf8.decode(studentResponse.bodyBytes));
          submissionData['alumno'] = {'nombre': studentData['nombre']};
        }

        return Submission.fromJson(submissionData);
      } else if (response.statusCode == 404) {
        throw SubmissionException('No se encontró la entrega especificada');
      } else if (response.statusCode == 403) {
        throw SubmissionException('No tienes permisos para ver esta entrega');
      } else {
        throw SubmissionException('No pudimos obtener los detalles de la entrega');
      }
    } catch (e) {
      if (e is SubmissionException) rethrow;
      throw SubmissionException('Error de conexión. Por favor, verifica tu internet');
    }
  }

  Future<Uint8List> getSubmissionImage(int submissionId, String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/entregas/imagen/$submissionId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else if (response.statusCode == 404) {
        throw SubmissionException('No se encontró la imagen de la entrega');
      } else if (response.statusCode == 403) {
        throw SubmissionException('No tienes permisos para ver esta imagen');
      } else {
        throw SubmissionException('No pudimos obtener la imagen de la entrega');
      }
    } catch (e) {
      if (e is SubmissionException) rethrow;
      throw SubmissionException('Error de conexión. Por favor, verifica tu internet');
    }
  }

  Future<void> evaluateSubmissionWithGemini(int entregaId, String token) async {
    try {
      final response = await _client.put(
        Uri.parse('$_baseUrl/entregas/evaluar-texto/$entregaId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return;
      } else if (response.statusCode == 404) {
        throw SubmissionException('No se encontró la entrega para evaluar');
      } else if (response.statusCode == 403) {
        throw SubmissionException('No tienes permisos para evaluar esta entrega');
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw SubmissionException(error['detail'] ?? 'No pudimos evaluar la entrega');
      }
    } catch (e) {
      if (e is SubmissionException) rethrow;
      throw SubmissionException('Error de conexión. Por favor, verifica tu internet');
    }
  }

  Future<List<Submission>> getStudentSubmissions(int alumnoId, int asignaturaId, String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/entregas/alumno/$alumnoId/asignatura/$asignaturaId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> decodedData = json.decode(utf8.decode(response.bodyBytes));
        return decodedData.map((json) => Submission.fromJson(json)).toList();
      } else if (response.statusCode == 404) {
        throw SubmissionException('No se encontraron entregas para este estudiante en la asignatura');
      } else if (response.statusCode == 403) {
        throw SubmissionException('No tienes permisos para ver estas entregas');
      } else {
        throw SubmissionException('No pudimos obtener las entregas del estudiante');
      }
    } catch (e) {
      if (e is SubmissionException) rethrow;
      throw SubmissionException('Error de conexión. Por favor, verifica tu internet');
    }
  }

  Future<String> processImageOCR(File image, String token) async {
    try {
      final httpClient = HttpClientFactory.createClient();
      
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/entregas/ocr/process'),
      );

      // Añadir el token de autorización
      request.headers['Authorization'] = 'Bearer $token';

      // Añadir la imagen
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          image.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      // Configurar un cliente HTTP que acepte certificados autofirmados
      final streamedResponse = await httpClient.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        return decodedData as String;
      } else if (response.statusCode == 400) {
        throw SubmissionException('No se pudo procesar la imagen. Asegúrate de que sea una imagen válida');
      } else if (response.statusCode == 413) {
        throw SubmissionException('La imagen es demasiado grande. Por favor, reduce su tamaño');
      } else {
        throw SubmissionException('No pudimos procesar el texto de la imagen');
      }
    } catch (e) {
      if (e is SubmissionException) rethrow;
      throw SubmissionException('Error de conexión. Por favor, verifica tu internet');
    }
  }

  Future<String> getSubmissionImageUrl(int submissionId, String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/entregas/$submissionId/imagen'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return data['url'];
      } else if (response.statusCode == 404) {
        throw SubmissionException('No se encontró la imagen de la entrega');
      } else if (response.statusCode == 403) {
        throw SubmissionException('No tienes permisos para ver esta imagen');
      } else {
        throw SubmissionException('No pudimos obtener la URL de la imagen');
      }
    } catch (e) {
      if (e is SubmissionException) rethrow;
      throw SubmissionException('Error de conexión. Por favor, verifica tu internet');
    }
  }

  Future<Uint8List> downloadSubmissionImage(int submissionId, String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/entregas/download/$submissionId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else if (response.statusCode == 404) {
        throw SubmissionException('No se encontró la imagen para descargar');
      } else if (response.statusCode == 403) {
        throw SubmissionException('No tienes permisos para descargar esta imagen');
      } else {
        throw SubmissionException('No pudimos descargar la imagen de la entrega');
      }
    } catch (e) {
      if (e is SubmissionException) rethrow;
      throw SubmissionException('Error de conexión. Por favor, verifica tu internet');
    }
  }
} 