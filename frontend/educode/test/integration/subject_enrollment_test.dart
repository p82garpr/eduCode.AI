import 'package:educode/features/auth/domain/models/user_model.dart';
import 'package:educode/features/auth/presentation/providers/auth_provider.dart';
import 'package:educode/features/courses/data/services/enrollment_service.dart';
import 'package:educode/features/courses/domain/models/subject_model.dart';
import 'package:educode/features/courses/presentation/providers/enrollment_provider.dart';
import 'package:educode/features/courses/presentation/providers/subjects_provider.dart';
import 'package:educode/features/courses/presentation/widgets/enrollment_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'subject_enrollment_test.mocks.dart';

// Clase de prueba para simular la matriculación exitosa en una asignatura
class TestEnrollmentSuccessWidget extends StatelessWidget {
  final int subjectId;
  final String subjectName;
  
  const TestEnrollmentSuccessWidget({
    Key? key, 
    required this.subjectId,
    required this.subjectName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => _enrollInSubject(context),
          child: const Text('Matricularme'),
        ),
      ),
    );
  }

  Future<void> _enrollInSubject(BuildContext context) async {
    // Simulamos que se abre el diálogo y se introduce el código
    final result = await EnrollmentDialog.show(context, subjectName);
    
    if (result == null) return; // Usuario canceló
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final enrollmentProvider = Provider.of<EnrollmentProvider>(context, listen: false);
    final subjectsProvider = Provider.of<SubjectsProvider>(context, listen: false);
    
    final token = authProvider.token;
    final userId = authProvider.currentUser?.id;

    if (token == null || userId == null) {
      print('Error: No hay sesión activa');
      return;
    }

    try {
      // Matricular al alumno en la asignatura
      await enrollmentProvider.enrollInSubject(
        userId.toString(),
        subjectId.toString(),
        result, // El código de acceso
        token,
      );

      // Recargar las asignaturas después de matricularse
      await subjectsProvider.loadSubjects(
        userId.toString(),
        'Alumno',
        token,
      );
    } catch (e) {
      print('Error en provider: $e');
    }
  }
}

// Clase de prueba para simular un error durante la matriculación
class TestEnrollmentErrorWidget extends StatelessWidget {
  final int subjectId;
  final String subjectName;
  
  const TestEnrollmentErrorWidget({
    Key? key, 
    required this.subjectId,
    required this.subjectName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => _enrollInSubject(context),
          child: const Text('Matricularme'),
        ),
      ),
    );
  }

  Future<void> _enrollInSubject(BuildContext context) async {
    // Simulamos que se abre el diálogo y se introduce el código
    final result = await EnrollmentDialog.show(context, subjectName);
    
    if (result == null) return; // Usuario canceló
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final enrollmentProvider = Provider.of<EnrollmentProvider>(context, listen: false);
    
    final token = authProvider.token;
    final userId = authProvider.currentUser?.id;

    if (token == null || userId == null) {
      print('Error: No hay sesión activa');
      return;
    }

    try {
      // Matricular al alumno en la asignatura (que fallará)
      await enrollmentProvider.enrollInSubject(
        userId.toString(),
        subjectId.toString(),
        result, // El código de acceso
        token,
      );
      
      // No se cargará la lista de asignaturas en caso de error
    } catch (e) {
      print('Error en provider: $e');
    }
  }
}

// Generar mocks para los servicios
@GenerateMocks([EnrollmentService, AuthProvider, SubjectsProvider])
void main() {
  late MockEnrollmentService mockEnrollmentService;
  late MockAuthProvider mockAuthProvider;
  late MockSubjectsProvider mockSubjectsProvider;

  setUp(() {
    mockEnrollmentService = MockEnrollmentService();
    mockAuthProvider = MockAuthProvider();
    mockSubjectsProvider = MockSubjectsProvider();
    
    // Desactivar animaciones para evitar problemas de timers
    TestWidgetsFlutterBinding.ensureInitialized();
    final binding = TestWidgetsFlutterBinding.instance;
    binding.window.devicePixelRatioTestValue = 1.0;
    binding.window.physicalSizeTestValue = const Size(1080, 2400);
  });

  group('Pruebas de Matriculación en Asignaturas', () {
    testWidgets('Verificar que la matriculación en asignatura funciona correctamente',
        (WidgetTester tester) async {
      // Configurar el mock de AuthProvider (como alumno)
      final userModel = UserModel(
        id: '1',
        nombre: 'Alumno',
        apellidos: 'Test',
        email: 'alumno@example.com',
        tipoUsuario: 'Alumno',
      );
      
      when(mockAuthProvider.currentUser).thenReturn(userModel);
      when(mockAuthProvider.token).thenReturn('token-test');
      when(mockAuthProvider.isAuthenticated).thenReturn(true);
      
      // Configurar el mock de la asignatura
      final mockSubject = Subject(
        id: 1,
        nombre: 'Programación Avanzada',
        descripcion: 'Curso de programación con Flutter y Dart',
        profesorId: 2,
        profesor: Profesor(
          id: 2,
          email: 'profesor@example.com',
          nombre: 'Profesor',
          apellidos: 'Test',
          tipoUsuario: 'Profesor',
        ),
        codigoAcceso: 'PROG2023',
      );
      
      // Configurar respuestas de los mocks
      when(mockEnrollmentService.enrollInSubject(any, any, any, any))
          .thenAnswer((_) async => null);
      
      when(mockSubjectsProvider.loadSubjects(any, any, any))
          .thenAnswer((_) async => null);
      
      // Construir el widget de prueba
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(
                value: mockAuthProvider,
              ),
              ChangeNotifierProvider<EnrollmentProvider>(
                create: (_) => EnrollmentProvider(mockEnrollmentService),
              ),
              ChangeNotifierProvider<SubjectsProvider>.value(
                value: mockSubjectsProvider,
              ),
            ],
            child: TestEnrollmentSuccessWidget(
              subjectId: mockSubject.id,
              subjectName: mockSubject.nombre,
            ),
          ),
        ),
      );
      
      // Pulsar botón de matriculación
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      
      // Verificar que se muestra el diálogo de inscripción
      expect(find.text('Inscribirse en Programación Avanzada'), findsOneWidget);
      
      // Introducir el código de acceso
      await tester.enterText(find.byType(TextFormField), 'PROG2023');
      await tester.pumpAndSettle();
      
      // Pulsar el botón de inscripción
      await tester.tap(find.text('Inscribirse'));
      await tester.pumpAndSettle();
      
      // Verificar que se llamó al método enrollInSubject con los parámetros correctos
      verify(mockEnrollmentService.enrollInSubject(
        '1', // ID del alumno
        '1', // ID de la asignatura
        'PROG2023', // Código de acceso
        'token-test', // Token
      )).called(1);
      
      // Verificar que se recargaron las asignaturas
      verify(mockSubjectsProvider.loadSubjects('1', 'Alumno', 'token-test')).called(1);
    });
    
    testWidgets('Verificar manejo de errores durante la matriculación',
        (WidgetTester tester) async {
      // Configurar el mock de AuthProvider (como alumno)
      final userModel = UserModel(
        id: '1',
        nombre: 'Alumno',
        apellidos: 'Test',
        email: 'alumno@example.com',
        tipoUsuario: 'Alumno',
      );
      
      when(mockAuthProvider.currentUser).thenReturn(userModel);
      when(mockAuthProvider.token).thenReturn('token-test');
      when(mockAuthProvider.isAuthenticated).thenReturn(true);
      
      // Configurar el mock de la asignatura
      final mockSubject = Subject(
        id: 1,
        nombre: 'Programación Avanzada',
        descripcion: 'Curso de programación con Flutter y Dart',
        profesorId: 2,
        profesor: Profesor(
          id: 2,
          email: 'profesor@example.com',
          nombre: 'Profesor',
          apellidos: 'Test',
          tipoUsuario: 'Profesor',
        ),
        codigoAcceso: 'PROG2023',
      );
      
      // Configurar el mock del EnrollmentService para simular un error
      when(mockEnrollmentService.enrollInSubject(any, any, any, any))
          .thenThrow(Exception('Código de acceso incorrecto'));
      
      // Construir el widget de prueba
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(
                value: mockAuthProvider,
              ),
              ChangeNotifierProvider<EnrollmentProvider>(
                create: (_) => EnrollmentProvider(mockEnrollmentService),
              ),
              ChangeNotifierProvider<SubjectsProvider>.value(
                value: mockSubjectsProvider,
              ),
            ],
            child: TestEnrollmentErrorWidget(
              subjectId: mockSubject.id,
              subjectName: mockSubject.nombre,
            ),
          ),
        ),
      );
      
      // Pulsar botón de matriculación
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      
      // Verificar que se muestra el diálogo de inscripción
      expect(find.text('Inscribirse en Programación Avanzada'), findsOneWidget);
      
      // Introducir el código de acceso
      await tester.enterText(find.byType(TextFormField), 'CODIGO_INCORRECTO');
      await tester.pumpAndSettle();
      
      // Pulsar el botón de inscripción
      await tester.tap(find.text('Inscribirse'));
      await tester.pumpAndSettle();
      
      // Verificar que se llamó al método enrollInSubject
      verify(mockEnrollmentService.enrollInSubject(any, any, any, any)).called(1);
      
      // Verificar que NO se recargaron las asignaturas
      verifyNever(mockSubjectsProvider.loadSubjects(any, any, any));
    });
  });
} 