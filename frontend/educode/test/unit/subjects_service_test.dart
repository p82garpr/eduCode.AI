import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:educode/features/courses/data/services/subjects_service.dart';
import 'package:educode/features/courses/domain/models/subject_model.dart';
import 'package:educode/core/config/app_config.dart';
import 'dart:convert';

// Generar archivo de mock automáticamente
@GenerateMocks([http.Client])
import 'subjects_service_test.mocks.dart';

void main() {
  group('SubjectsService', () {
    late MockClient mockClient;
    late SubjectsService subjectsService;
    final baseUrl = AppConfig.apiBaseUrl;

    setUp(() {
      mockClient = MockClient();
      subjectsService = SubjectsService(client: mockClient);
    });

    test('getSubjectDetail devuelve un objeto Subject cuando la petición es exitosa', () async {
      // Arrange - Preparar los datos para la prueba
      const subjectId = 1;
      const token = 'test_token';
      final jsonResponse = {
        'id': subjectId,
        'nombre': 'Programación',
        'descripcion': 'Curso de programación',
        'codigo_acceso': 'ABC123',
        'profesor_id': 1,
        'profesor': {
          'id': 1,
          'nombre': 'Profesor',
          'apellidos': 'Test',
          'email': 'profesor@example.com',
          'tipo_usuario': 'Profesor'
        }
      };

      // Configurar el comportamiento del mock correctamente
      when(mockClient.get(
        Uri.parse('$baseUrl/asignaturas/$subjectId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      )).thenAnswer((_) async => http.Response(json.encode(jsonResponse), 200));

      // Act - Ejecutar la función a probar
      final result = await subjectsService.getSubjectDetail(subjectId, token);

      // Assert - Verificar que el resultado es el esperado
      expect(result, isA<Subject>());
      expect(result.id, equals(subjectId));
      expect(result.nombre, equals('Programación'));
      expect(result.descripcion, equals('Curso de programación'));
    });

    test('getSubjectDetail lanza una excepción cuando la petición falla', () async {
      // Arrange - Preparar el escenario para que falle
      const subjectId = 1;
      const token = 'test_token';

      // Configurar el mock para que devuelva un error, sin usar any() en la URL
      when(mockClient.get(
        Uri.parse('$baseUrl/asignaturas/$subjectId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      )).thenAnswer((_) async => http.Response('Error en el servidor', 500));

      // Act y Assert - Verificar que se lanza una excepción
      expect(
        () => subjectsService.getSubjectDetail(subjectId, token),
        throwsException,
      );
    });
  });
} 