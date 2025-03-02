import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:educode/features/auth/data/services/auth_service.dart';
import 'package:educode/features/auth/domain/models/user_model.dart';
import 'package:educode/core/config/app_config.dart';
import 'dart:convert';

// Generar archivo de mock automáticamente
@GenerateMocks([http.Client])
import 'auth_service_test.mocks.dart';

void main() {
  group('AuthService', () {
    late MockClient mockClient;
    late AuthService authService;
    final baseUrl = AppConfig.apiBaseUrl;

    setUp(() {
      mockClient = MockClient();
      authService = AuthService(client: mockClient);
    });

    group('login', () {
      test('devuelve un token cuando las credenciales son correctas', () async {
        // Arrange - Preparar los datos para la prueba
        const email = 'usuario@example.com';
        const password = 'password123';
        const testToken = 'test_token_12345';
        
        final jsonResponse = {
          'access_token': testToken
        };

        // Configurar el comportamiento del mock
        when(mockClient.post(
          Uri.parse('$baseUrl/login'),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'username': email,
            'password': password,
          },
        )).thenAnswer((_) async => http.Response(json.encode(jsonResponse), 200));

        // Act - Ejecutar la función a probar
        final result = await authService.login(email, password);
        
        // Assert - Verificar el resultado esperado
        expect(result, equals(testToken));
      });

      test('lanza una excepción cuando las credenciales son incorrectas', () async {
        // Arrange - Preparar para el caso de error
        const email = 'usuario@example.com';
        const password = 'password_incorrecto';
        
        // Configurar el mock para devolver un error
        when(mockClient.post(
          Uri.parse('$baseUrl/login'),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'username': email,
            'password': password,
          },
        )).thenAnswer((_) async => http.Response('{"detail": "Credenciales inválidas"}', 401));

        // Act & Assert - Ejecutar y verificar que se lanza excepción
        expect(
          () => authService.login(email, password),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('getUserInfo', () {
      test('devuelve un UserModel cuando el token es válido', () async {
        // Arrange - Preparar los datos para la prueba
        const token = 'valid_token';
        final jsonResponse = {
          'id': '1',
          'nombre': 'Usuario',
          'apellidos': 'Test',
          'email': 'usuario@example.com',
          'tipo_usuario': 'Alumno'
        };

        // Configurar el mock
        when(mockClient.get(
          Uri.parse('$baseUrl/me'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        )).thenAnswer((_) async => http.Response(json.encode(jsonResponse), 200));

        // Act - Ejecutar la función a probar
        final result = await authService.getUserInfo(token);
        
        // Assert - Verificar el resultado esperado
        expect(result, isA<UserModel>());
        expect(result.nombre, equals('Usuario'));
        expect(result.apellidos, equals('Test'));
        expect(result.email, equals('usuario@example.com'));
      });

      test('lanza una excepción cuando el token es inválido', () async {
        // Arrange - Preparar para el caso de error
        const token = 'invalid_token';
        
        // Configurar el mock para devolver un error
        when(mockClient.get(
          Uri.parse('$baseUrl/me'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        )).thenAnswer((_) async => http.Response('{"detail": "Token inválido"}', 401));

        // Act & Assert - Ejecutar y verificar que se lanza excepción
        expect(
          () => authService.getUserInfo(token),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('register', () {
      test('devuelve un UserModel cuando el registro es exitoso', () async {
        // Arrange - Preparar los datos para la prueba
        const name = 'Nuevo';
        const lastName = 'Usuario';
        const email = 'nuevo@example.com';
        const password = 'password123';
        
        final jsonResponse = {
          'id': '2',
          'nombre': name,
          'apellidos': lastName,
          'email': email,
          'tipo_usuario': 'Alumno'
        };

        // Configurar el mock
        when(mockClient.post(
          Uri.parse('$baseUrl/registro'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'email': email,
            'nombre': name,
            'apellidos': lastName,
            'password': password,
            'tipo_usuario': 'Alumno',
          }),
        )).thenAnswer((_) async => http.Response(json.encode(jsonResponse), 201));

        // Act - Ejecutar la función a probar
        final result = await authService.register(name, lastName, email, password);
        
        // Assert - Verificar el resultado esperado
        expect(result, isA<UserModel>());
        expect(result.nombre, equals(name));
        expect(result.apellidos, equals(lastName));
        expect(result.email, equals(email));
      });

      test('lanza una excepción cuando el email ya está registrado', () async {
        // Arrange - Preparar para el caso de error
        const name = 'Nuevo';
        const lastName = 'Usuario';
        const email = 'existente@example.com';
        const password = 'password123';
        
        // Configurar el mock para devolver un error
        when(mockClient.post(
          Uri.parse('$baseUrl/registro'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'email': email,
            'nombre': name,
            'apellidos': lastName,
            'password': password,
            'tipo_usuario': 'Alumno',
          }),
        )).thenAnswer((_) async => http.Response('{"detail": "El email ya está registrado"}', 400));

        // Act & Assert - Ejecutar y verificar que se lanza excepción
        expect(
          () => authService.register(name, lastName, email, password),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
} 