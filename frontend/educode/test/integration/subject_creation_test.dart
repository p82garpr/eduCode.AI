import 'package:educode/features/auth/domain/models/user_model.dart';
import 'package:educode/features/auth/presentation/providers/auth_provider.dart';
import 'package:educode/features/courses/data/services/subjects_service.dart';
import 'package:educode/features/courses/domain/models/subject_model.dart';
import 'package:educode/features/courses/presentation/providers/subjects_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'subject_creation_test.mocks.dart';

// Clase de prueba para simular el diálogo de creación de asignaturas (caso de éxito)
class TestCreateSubjectSuccessWidget extends StatelessWidget {
  const TestCreateSubjectSuccessWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => _createSubject(context),
          child: const Text('Crear Asignatura'),
        ),
      ),
    );
  }

  Future<void> _createSubject(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final subjectsProvider = Provider.of<SubjectsProvider>(context, listen: false);
    final token = authProvider.token;
    final userId = authProvider.currentUser?.id;

    if (token == null || userId == null) {
      print('Error: No hay sesión activa');
      return;
    }

    try {
      // Crear la asignatura con datos de prueba
      await subjectsProvider.createSubject({
        'nombre': 'Programación Avanzada',
        'descripcion': 'Curso de programación con Flutter y Dart',
        'codigo_acceso': 'PROG2023',
        'profesor_id': userId,
      }, token);

      // Recargar las asignaturas después de una creación exitosa
      await subjectsProvider.loadSubjects(
        userId.toString(),
        'Profesor',
        token,
      );
    } catch (e) {
      print('Error en provider: $e');
    }
  }
}

// Clase de prueba para simular el diálogo de creación de asignaturas (caso de error)
class TestCreateSubjectErrorWidget extends StatelessWidget {
  const TestCreateSubjectErrorWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => _createSubject(context),
          child: const Text('Crear Asignatura'),
        ),
      ),
    );
  }

  Future<void> _createSubject(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final subjectsProvider = Provider.of<SubjectsProvider>(context, listen: false);
    final token = authProvider.token;
    final userId = authProvider.currentUser?.id;

    if (token == null || userId == null) {
      print('Error: No hay sesión activa');
      return;
    }

    try {
      // Crear la asignatura con datos de prueba
      await subjectsProvider.createSubject({
        'nombre': 'Programación Avanzada',
        'descripcion': 'Curso de programación con Flutter y Dart',
        'codigo_acceso': 'PROG2023',
        'profesor_id': userId,
      }, token);

      // Esta parte NO se ejecutará en el caso de error
      // No se debe llamar a loadSubjects aquí
    } catch (e) {
      print('Error en provider: $e');
      // No hacemos nada más en caso de error
    }
  }
}

// Generar mocks para los servicios
@GenerateMocks([SubjectsService, AuthProvider])
void main() {
  late MockSubjectsService mockSubjectsService;
  late MockAuthProvider mockAuthProvider;

  setUp(() {
    mockSubjectsService = MockSubjectsService();
    mockAuthProvider = MockAuthProvider();
    
    // Desactivar animaciones para evitar problemas de timers
    TestWidgetsFlutterBinding.ensureInitialized();
    final binding = TestWidgetsFlutterBinding.instance;
    binding.window.devicePixelRatioTestValue = 1.0;
    binding.window.physicalSizeTestValue = const Size(1080, 2400);
  });

  group('Pruebas de Creación de Asignaturas', () {
    testWidgets('Verificar que el servicio de creación de asignaturas es llamado con los datos correctos', 
        (WidgetTester tester) async {
      // Configurar mocks
      final userModel = UserModel(
        id: '1',
        nombre: 'Profesor',
        apellidos: 'Test',
        email: 'profesor@example.com',
        tipoUsuario: 'Profesor',
      );
      
      // Configurar el mock del AuthProvider
      when(mockAuthProvider.currentUser).thenReturn(userModel);
      when(mockAuthProvider.token).thenReturn('token-test');
      when(mockAuthProvider.isAuthenticated).thenReturn(true);
      
      // Configurar el mock del SubjectsService
      final mockSubject = Subject(
        id: 1,
        nombre: 'Programación Avanzada',
        descripcion: 'Curso de programación con Flutter y Dart',
        profesorId: 1,
        profesor: Profesor(
          id: 1,
          email: 'profesor@example.com',
          nombre: 'Profesor',
          apellidos: 'Test',
          tipoUsuario: 'Profesor',
        ),
        codigoAcceso: 'PROG2023',
      );
      
      when(mockSubjectsService.createSubject(any, any)).thenAnswer((_) async => mockSubject);
      when(mockSubjectsService.getCoursesByUser(any, any, any)).thenAnswer((_) async => [mockSubject]);
      
      // Construir el widget con los providers necesarios
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(
                value: mockAuthProvider,
              ),
              ChangeNotifierProvider<SubjectsProvider>(
                create: (_) => SubjectsProvider(mockSubjectsService),
              ),
            ],
            child: const TestCreateSubjectSuccessWidget(),
          ),
        ),
      );
      
      // Pulsar botón de creación de asignatura
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump(const Duration(milliseconds: 100));
      
      // Verificar que se llamó al método createSubject con los parámetros correctos
      verify(mockSubjectsService.createSubject({
        'nombre': 'Programación Avanzada',
        'descripcion': 'Curso de programación con Flutter y Dart',
        'codigo_acceso': 'PROG2023',
        'profesor_id': '1',
      }, 'token-test')).called(1);
      
      // Verificar que se recargaron las asignaturas
      verify(mockSubjectsService.getCoursesByUser('1', 'Profesor', 'token-test')).called(1);
    });
    
    testWidgets('Verificar manejo de errores en la creación de asignaturas', 
        (WidgetTester tester) async {
      // Configurar mocks
      final userModel = UserModel(
        id: '1',
        nombre: 'Profesor',
        apellidos: 'Test',
        email: 'profesor@example.com',
        tipoUsuario: 'Profesor',
      );
      
      // Configurar el mock del AuthProvider
      when(mockAuthProvider.currentUser).thenReturn(userModel);
      when(mockAuthProvider.token).thenReturn('token-test');
      when(mockAuthProvider.isAuthenticated).thenReturn(true);
      
      // Configurar el mock del SubjectsService para simular un error
      when(mockSubjectsService.createSubject(any, any))
          .thenThrow(Exception('Error al crear la asignatura'));
      
      // Construir el widget con los providers necesarios
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(
                value: mockAuthProvider,
              ),
              ChangeNotifierProvider<SubjectsProvider>(
                create: (_) => SubjectsProvider(mockSubjectsService),
              ),
            ],
            child: const TestCreateSubjectErrorWidget(),
          ),
        ),
      );
      
      // Pulsar botón de creación de asignatura
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump(const Duration(milliseconds: 100));
      
      // Verificar que se llamó al método createSubject
      verify(mockSubjectsService.createSubject(any, any)).called(1);
      
      // Verificar que NO se recargaron las asignaturas
      verifyNever(mockSubjectsService.getCoursesByUser(any, any, any));
    });
  });
} 