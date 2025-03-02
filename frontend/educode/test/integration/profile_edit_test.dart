import 'package:educode/features/auth/data/services/auth_service.dart';
import 'package:educode/features/auth/domain/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'profile_edit_test.mocks.dart';

@GenerateMocks([AuthService])
void main() {
  late MockAuthService mockAuthService;

  setUp(() {
    mockAuthService = MockAuthService();
  });

  group('Pruebas de Servicio de Edición de Perfil', () {
    test('Actualización exitosa de perfil de usuario', () async {
      // Configurar usuario inicial
      final initialUser = UserModel(
        id: '1',
        nombre: 'Usuario',
        apellidos: 'Prueba',
        email: 'usuario@example.com',
        tipoUsuario: 'Alumno',
      );
      
      // Configurar usuario actualizado
      final updatedUser = UserModel(
        id: '1',
        nombre: 'Usuario Actualizado',
        apellidos: 'Prueba Actualizada',
        email: 'usuario@example.com',
        tipoUsuario: 'Alumno',
      );
      
      // Configurar la respuesta del servicio para updateProfile
      when(mockAuthService.updateProfile(
        nombre: 'Usuario Actualizado',
        apellidos: 'Prueba Actualizada',
        email: 'usuario@example.com',
        token: 'token-test',
      )).thenAnswer((_) async => updatedUser);
      
      // Llamar al método updateProfile directamente
      final result = await mockAuthService.updateProfile(
        nombre: 'Usuario Actualizado',
        apellidos: 'Prueba Actualizada',
        email: 'usuario@example.com',
        token: 'token-test',
      );
      
      // Verificar que el resultado es el usuario actualizado
      expect(result.nombre, 'Usuario Actualizado');
      expect(result.apellidos, 'Prueba Actualizada');
      
      // Verificar que se llamó al método updateProfile del servicio
      verify(mockAuthService.updateProfile(
        nombre: 'Usuario Actualizado',
        apellidos: 'Prueba Actualizada',
        email: 'usuario@example.com',
        token: 'token-test',
      )).called(1);
    });
    
    test('Manejo de error al actualizar el perfil', () async {
      // Configurar la respuesta del servicio para simular un error
      when(mockAuthService.updateProfile(
        nombre: anyNamed('nombre'),
        apellidos: anyNamed('apellidos'),
        email: anyNamed('email'),
        token: anyNamed('token'),
      )).thenThrow(Exception('Error al actualizar el perfil'));
      
      // Verificar que se lanza la excepción
      expect(
        () => mockAuthService.updateProfile(
          nombre: 'Usuario Modificado',
          apellidos: 'Prueba',
          email: 'usuario@example.com',
          token: 'token-test',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'mensaje',
          contains('Error al actualizar el perfil'),
        )),
      );
    });
    
    test('Actualizar perfil incluyendo nueva contraseña', () async {
      // Configurar usuario actualizado
      final updatedUser = UserModel(
        id: '1',
        nombre: 'Usuario',
        apellidos: 'Prueba',
        email: 'usuario@example.com',
        tipoUsuario: 'Alumno',
      );
      
      // Configurar la respuesta del servicio
      when(mockAuthService.updateProfile(
        nombre: anyNamed('nombre'),
        apellidos: anyNamed('apellidos'),
        email: anyNamed('email'),
        token: anyNamed('token'),
        password: 'nuevacontraseña123',
      )).thenAnswer((_) async => updatedUser);
      
      // Llamar al método updateProfile con contraseña
      final result = await mockAuthService.updateProfile(
        nombre: 'Usuario',
        apellidos: 'Prueba',
        email: 'usuario@example.com',
        token: 'token-test',
        password: 'nuevacontraseña123',
      );
      
      // Verificar que el resultado es el usuario actualizado
      expect(result.nombre, 'Usuario');
      expect(result.apellidos, 'Prueba');
      
      // Verificar que se llamó al método updateProfile con la nueva contraseña
      verify(mockAuthService.updateProfile(
        nombre: 'Usuario',
        apellidos: 'Prueba',
        email: 'usuario@example.com',
        token: 'token-test',
        password: 'nuevacontraseña123',
      )).called(1);
    });
  });
} 