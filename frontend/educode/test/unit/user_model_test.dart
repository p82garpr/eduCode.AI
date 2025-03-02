import 'package:flutter_test/flutter_test.dart';
import 'package:educode/features/auth/domain/models/user_model.dart';

void main() {
  group('UserModel', () {
    test('se debe crear correctamente desde un objeto JSON', () {
      // Preparar datos de prueba
      final jsonData = {
        'id': 1,
        'nombre': 'Juan',
        'apellidos': 'Pérez',
        'email': 'juan.perez@example.com',
        'tipo_usuario': 'Alumno',
      };
      
      // Crear modelo desde JSON
      final user = UserModel.fromJson(jsonData);
      
      // Verificar que los datos se mapean correctamente
      expect(user.id, '1');
      expect(user.nombre, 'Juan');
      expect(user.apellidos, 'Pérez');
      expect(user.email, 'juan.perez@example.com');
      expect(user.tipoUsuario, 'Alumno');
    });
    
    test('se debe convertir correctamente a un objeto JSON', () {
      // Crear un modelo de usuario
      final user = UserModel(
        id: '2',
        nombre: 'María',
        apellidos: 'González',
        email: 'maria.gonzalez@example.com',
        tipoUsuario: 'Profesor',
      );
      
      // Convertir a JSON
      final jsonData = user.toJson();
      
      // Verificar que los datos se mapean correctamente
      expect(jsonData['id'], '2');
      expect(jsonData['nombre'], 'María');
      expect(jsonData['apellidos'], 'González');
      expect(jsonData['email'], 'maria.gonzalez@example.com');
      expect(jsonData['tipo_usuario'], 'Profesor');
    });
    
    test('debe mantener la integridad de los datos en una conversión bidireccional', () {
      // Crear un modelo de usuario
      final originalUser = UserModel(
        id: '3',
        nombre: 'Carlos',
        apellidos: 'López',
        email: 'carlos.lopez@example.com',
        tipoUsuario: 'Alumno',
      );
      
      // Convertir a JSON y luego de vuelta a UserModel
      final jsonData = originalUser.toJson();
      final recoveredUser = UserModel.fromJson(jsonData);
      
      // Verificar que los datos se mantienen
      expect(recoveredUser.id, originalUser.id);
      expect(recoveredUser.nombre, originalUser.nombre);
      expect(recoveredUser.apellidos, originalUser.apellidos);
      expect(recoveredUser.email, originalUser.email);
      expect(recoveredUser.tipoUsuario, originalUser.tipoUsuario);
    });
    
    test('debe manejar correctamente valores numéricos y string para el ID', () {
      // Crear JSON con ID numérico
      final jsonWithNumberId = {
        'id': 4,
        'nombre': 'Ana',
        'apellidos': 'Martínez',
        'email': 'ana.martinez@example.com',
        'tipo_usuario': 'Alumno',
      };
      
      // Crear JSON con ID string
      final jsonWithStringId = {
        'id': '5',
        'nombre': 'Pedro',
        'apellidos': 'Sánchez',
        'email': 'pedro.sanchez@example.com',
        'tipo_usuario': 'Profesor',
      };
      
      // Crear modelos
      final userWithNumberId = UserModel.fromJson(jsonWithNumberId);
      final userWithStringId = UserModel.fromJson(jsonWithStringId);
      
      // Verificar que ambos IDs se convierten correctamente a string
      expect(userWithNumberId.id, '4');
      expect(userWithStringId.id, '5');
    });
  });
} 