import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:educode/features/courses/domain/models/subject_model.dart';
import 'package:educode/features/courses/presentation/widgets/edit_subject_dialog.dart';

void main() {
  group('EditSubjectDialog', () {
    // Crear un modelo de asignatura para las pruebas
    final testSubject = Subject(
      id: 1,
      nombre: 'Matemáticas',
      descripcion: 'Curso de matemáticas avanzadas',
      codigoAcceso: 'MATH123',
      profesorId: 1,
      profesor: Profesor(
        id: 1,
        nombre: 'Juan',
        apellidos: 'Pérez',
        email: 'juan.perez@example.com',
        tipoUsuario: 'Profesor',
      ),
    );

    testWidgets('Muestra los datos de la asignatura correctamente', (WidgetTester tester) async {
      // Construir el widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditSubjectDialog(
              subject: testSubject,
            ),
          ),
        ),
      );

      // Verificar que el título del diálogo es correcto
      expect(find.text('Editar Asignatura'), findsOneWidget);

      // Verificar que los campos muestran los valores iniciales correctos
      expect(find.text('Matemáticas'), findsOneWidget);
      expect(find.text('Curso de matemáticas avanzadas'), findsOneWidget);
    });

    testWidgets('Permite editar campos y muestra los valores actualizados', (WidgetTester tester) async {
      // Construir el widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditSubjectDialog(
              subject: testSubject,
            ),
          ),
        ),
      );

      // Encontrar los TextFormFields
      final nombreField = find.ancestor(
        of: find.text('Nombre'),
        matching: find.byType(TextFormField),
      );
      
      final descripcionField = find.ancestor(
        of: find.text('Descripción'),
        matching: find.byType(TextFormField),
      );

      // Verificar que los campos existen
      expect(nombreField, findsOneWidget);
      expect(descripcionField, findsOneWidget);

      // Editar el campo de nombre
      await tester.enterText(nombreField, 'Matemáticas Modificadas');
      
      // Verificar que el valor se actualizó después de ingresarlo
      final nombreController = tester.widget<TextFormField>(nombreField).controller;
      expect(nombreController?.text, equals('Matemáticas Modificadas'));

      // Editar el campo de descripción
      await tester.enterText(descripcionField, 'Descripción modificada');
      
      // Verificar que el valor se actualizó después de ingresarlo
      final descripcionController = tester.widget<TextFormField>(descripcionField).controller;
      expect(descripcionController?.text, equals('Descripción modificada'));

      // Verificar que el botón de guardar existe
      expect(find.text('Guardar'), findsOneWidget);
    });
  });
} 