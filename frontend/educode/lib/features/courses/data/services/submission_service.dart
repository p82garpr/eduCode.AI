import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/config/app_config.dart';

import '../../domain/models/submission_model.dart';
import 'package:http_parser/http_parser.dart';

class SubmissionService {
  final http.Client _client;
  final String _baseUrl = AppConfig.apiBaseUrl;

  SubmissionService({http.Client? client}) : _client = client ?? http.Client();

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
      } else {
        throw Exception('Error al obtener las entregas: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: ${e.toString()}');
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
          'comentarios': "Evaluado manualmente por el profesor", // Para que se tenga en cuenta que es evaluado manualmente por el profesor
        }),
      );

      if (response.statusCode != 200) {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(error['detail'] ?? 'Error al calificar la entrega');
      }
    } catch (e) {
      throw Exception('Error al calificar la entrega: ${e.toString()}');
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
          return null; // No hay entrega
        } else {
          throw Exception('Error al obtener la entrega: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Error en SubjectsService.getStudentSubmission: $e');
        rethrow;
      } 
    }

  Future<Submission?> getStudentSubmission2(int alumnoId, int actividadId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/entregas/alumno/$alumnoId/actividad/$actividadId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decodedData = json.decode(utf8.decode(response.bodyBytes));
        return Submission.fromJson(decodedData);
      } else {
        throw Exception('Error al obtener la entrega: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error en SubjectsService.getStudentSubmission2: $e');
      rethrow;
    }
  }

  Future<Submission> submitActivity(int activityId, String solution, String token, {File? image}) async {
    try {
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

      // Enviar la petición
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Error al enviar la entrega: ${response.statusCode}');
      }
      
      return Submission.fromJson(json.decode(response.body));
    } catch (e) {
      debugPrint('Error en SubjectsService.submitActivity: $e');
      rethrow;
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
        
        // Obtener los detalles del alumno
        final studentResponse = await http.get(
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
      } else {
        throw Exception('Error al obtener los detalles de la entrega');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
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
      } else {
        throw Exception('Error al obtener la imagen de la entrega');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }


  Future<void> evaluateSubmissionWithGemini(int entregaId, String token) async {
    try {
      final response = await _client.put(
        Uri.parse('$_baseUrl/entregas/evaluar-texto-gemini/$entregaId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(error['detail'] ?? 'Error al evaluar la entrega: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error en SubjectsService.evaluateSubmissionWithGemini: $e');
      rethrow;
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
      } else {
        throw Exception('Error al obtener las entregas: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error en SubjectsService.getStudentSubmissions: $e');
      rethrow;
      }
      
  }

  Future<String> processImageOCR(File image, String token) async {
    try {
      // Crear el request multipart
      final request = http.MultipartRequest(
        'POST',
        //Uri.parse('$_baseUrl/entregas/ocr/process'),
        Uri.parse('$_baseUrl/entregas/ocr/process-uco'),
        
        
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

      // Enviar la petición
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final decodedData = json.decode(responseBody);
        return decodedData as String;
      } else {
        throw Exception('Error al procesar la imagen: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error en SubjectsService.processImageOCR: $e');
      rethrow;
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
      } else {
        throw Exception('Error al obtener la URL de la imagen: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: ${e.toString()}');
    }
  }
} 