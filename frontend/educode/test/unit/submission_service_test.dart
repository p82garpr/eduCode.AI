import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:educode/features/courses/data/services/submission_service.dart';
import 'package:educode/features/courses/domain/models/submission_model.dart';
import 'package:educode/core/config/app_config.dart';
import 'dart:convert';
import 'dart:typed_data';

// Mock manual para http.Client
class MockClient extends Mock implements http.Client {}

void main() {
  group('SubmissionService', () {
    late MockClient mockClient;
    late SubmissionService submissionService;
    final baseUrl = AppConfig.apiBaseUrl;

    setUp(() {
      mockClient = MockClient();
      submissionService = SubmissionService(client: mockClient);
    });

    group('getActivitySubmissions', () {
      test('devuelve una lista de entregas cuando la petición es exitosa', () async {
        // Arrange - Preparar los datos para la prueba
        const activityId = 1;
        const token = 'test_token';
        
        final jsonResponse = [
          {
            'id': 1,
            'fecha_entrega': '2023-05-15T10:30:00Z',
            'comentarios': 'Buen trabajo',
            'calificacion': 8.5,
            'actividad_id': activityId,
            'alumno_id': 101,
            'nombre_archivo': 'tarea1.jpg',
            'tipo_imagen': 'image/jpeg',
            'texto_ocr': 'Contenido de la entrega'
          },
          {
            'id': 2,
            'fecha_entrega': '2023-05-16T11:45:00Z',
            'comentarios': null,
            'calificacion': null,
            'actividad_id': activityId,
            'alumno_id': 102,
            'nombre_archivo': 'tarea2.jpg',
            'tipo_imagen': 'image/jpeg',
            'texto_ocr': 'Otra entrega'
          }
        ];

        // Configurar el comportamiento del mock
        when(mockClient.get(
          Uri.parse('$baseUrl/entregas/actividad/$activityId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        )).thenAnswer((_) async => http.Response(
          json.encode(jsonResponse), 
          200, 
          headers: {'content-type': 'application/json; charset=utf-8'}
        ));

        // Act - Ejecutar la función a probar
        final result = await submissionService.getActivitySubmissions(activityId, token);
        
        // Assert - Verificar el resultado esperado
        expect(result, isA<List<Submission>>());
        expect(result.length, equals(2));
        expect(result[0].id, equals(1));
        expect(result[0].calificacion, equals(8.5));
        expect(result[1].id, equals(2));
        expect(result[1].calificacion, isNull);
      });

      test('lanza una excepción cuando la petición falla', () async {
        // Arrange - Preparar para el caso de error
        const activityId = 1;
        const token = 'test_token';
        
        // Configurar el mock para devolver un error
        when(mockClient.get(
          Uri.parse('$baseUrl/entregas/actividad/$activityId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        )).thenAnswer((_) async => http.Response('Error del servidor', 500));

        // Act & Assert - Ejecutar y verificar que se lanza excepción
        expect(
          () => submissionService.getActivitySubmissions(activityId, token),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('gradeSubmission', () {
      test('califica una entrega exitosamente', () async {
        // Arrange - Preparar los datos para la prueba
        const submissionId = 1;
        const grade = 9.5;
        const token = 'test_token';
        
        // Configurar el comportamiento del mock
        when(mockClient.patch(
          Uri.parse('$baseUrl/entregas/$submissionId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'calificacion': grade,
            'comentarios': "Evaluado manualmente por el profesor",
          }),
        )).thenAnswer((_) async => http.Response('', 200));

        // Act - Ejecutar la función a probar
        // El método no devuelve nada, pero no debería lanzar excepciones
        await expectLater(
          () => submissionService.gradeSubmission(submissionId, grade, token),
          returnsNormally,
        );
      });

      test('lanza una excepción cuando la petición de calificación falla', () async {
        // Arrange - Preparar para el caso de error
        const submissionId = 1;
        const grade = 9.5;
        const token = 'test_token';
        
        // Configurar el mock para devolver un error
        when(mockClient.patch(
          Uri.parse('$baseUrl/entregas/$submissionId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'calificacion': grade,
            'comentarios': "Evaluado manualmente por el profesor",
          }),
        )).thenAnswer((_) async => http.Response(
          json.encode({'detail': 'Error al calificar'}), 
          400,
          headers: {'content-type': 'application/json; charset=utf-8'}
        ));

        // Act & Assert - Ejecutar y verificar que se lanza excepción
        expect(
          () => submissionService.gradeSubmission(submissionId, grade, token),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('getStudentSubmission', () {
      test('devuelve una entrega cuando existe', () async {
        // Arrange - Preparar los datos para la prueba
        const submissionId = 1;
        const token = 'test_token';
        
        final jsonResponse = {
          'id': submissionId,
          'fecha_entrega': '2023-05-15T10:30:00Z',
          'comentarios': 'Buen trabajo',
          'calificacion': 8.5,
          'actividad_id': 10,
          'alumno_id': 101,
          'nombre_archivo': 'tarea1.jpg',
          'tipo_imagen': 'image/jpeg',
          'texto_ocr': 'Contenido de la entrega'
        };

        // Configurar el comportamiento del mock
        when(mockClient.get(
          Uri.parse('$baseUrl/entregas/$submissionId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )).thenAnswer((_) async => http.Response(
          json.encode(jsonResponse), 
          200,
          headers: {'content-type': 'application/json; charset=utf-8'}
        ));

        // Act - Ejecutar la función a probar
        final result = await submissionService.getStudentSubmission(submissionId, token);
        
        // Assert - Verificar el resultado esperado
        expect(result, isA<Submission>());
        expect(result?.id, equals(submissionId));
        expect(result?.calificacion, equals(8.5));
      });

      test('devuelve null cuando no existe la entrega', () async {
        // Arrange - Preparar para el caso de no encontrar la entrega
        const submissionId = 999;
        const token = 'test_token';
        
        // Configurar el mock para devolver un 404
        when(mockClient.get(
          Uri.parse('$baseUrl/entregas/$submissionId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )).thenAnswer((_) async => http.Response('', 404));

        // Act - Ejecutar la función a probar
        final result = await submissionService.getStudentSubmission(submissionId, token);
        
        // Assert - Verificar que el resultado es null
        expect(result, isNull);
      });

      test('lanza una excepción cuando la petición falla por un error diferente a 404', () async {
        // Arrange - Preparar para el caso de error
        const submissionId = 1;
        const token = 'test_token';
        
        // Configurar el mock para devolver un error que no sea 404
        when(mockClient.get(
          Uri.parse('$baseUrl/entregas/$submissionId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )).thenAnswer((_) async => http.Response('Error del servidor', 500));

        // Act & Assert - Ejecutar y verificar que se lanza excepción
        expect(
          () => submissionService.getStudentSubmission(submissionId, token),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('getSubmissionImage', () {
      test('devuelve los bytes de la imagen cuando la petición es exitosa', () async {
        // Arrange - Preparar los datos para la prueba
        const submissionId = 1;
        const token = 'test_token';
        
        // Crear bytes de prueba para una imagen
        final imageBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

        // Configurar el comportamiento del mock
        when(mockClient.get(
          Uri.parse('$baseUrl/entregas/imagen/$submissionId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        )).thenAnswer((_) async => http.Response.bytes(imageBytes, 200));

        // Act - Ejecutar la función a probar
        final result = await submissionService.getSubmissionImage(submissionId, token);
        
        // Assert - Verificar el resultado esperado
        expect(result, isA<Uint8List>());
        expect(result, equals(imageBytes));
      });

      test('lanza una excepción cuando la petición falla', () async {
        // Arrange - Preparar para el caso de error
        const submissionId = 1;
        const token = 'test_token';
        
        // Configurar el mock para devolver un error
        when(mockClient.get(
          Uri.parse('$baseUrl/entregas/imagen/$submissionId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        )).thenAnswer((_) async => http.Response('Error del servidor', 500));

        // Act & Assert - Ejecutar y verificar que se lanza excepción
        expect(
          () => submissionService.getSubmissionImage(submissionId, token),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
} 