import 'package:educode/features/auth/domain/models/user_model.dart';
import 'package:educode/features/auth/presentation/providers/auth_provider.dart';
import 'package:educode/features/courses/data/services/activity_service.dart';
import 'package:educode/features/courses/data/services/submission_service.dart';
import 'package:educode/features/courses/domain/models/activity_model.dart';
import 'package:educode/features/courses/domain/models/submission_model.dart';
import 'package:educode/features/courses/presentation/providers/activity_provider.dart';
import 'package:educode/features/courses/presentation/providers/submission_provider.dart';
import 'package:educode/features/courses/presentation/views/student_activity_submission_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'submission_test.mocks.dart';

// Generar mocks para los servicios y providers necesarios
@GenerateMocks([SubmissionService, ActivityService, AuthProvider])
void main() {
  late MockSubmissionService mockSubmissionService;
  late MockActivityService mockActivityService;
  late MockAuthProvider mockAuthProvider;

  setUp(() {
    mockSubmissionService = MockSubmissionService();
    mockActivityService = MockActivityService();
    mockAuthProvider = MockAuthProvider();
    
    // Desactivar animaciones para evitar problemas de timers
    TestWidgetsFlutterBinding.ensureInitialized();
    final binding = TestWidgetsFlutterBinding.instance;
    binding.window.devicePixelRatioTestValue = 1.0;
    binding.window.physicalSizeTestValue = const Size(1200, 2400); // Pantalla más grande para evitar desbordamientos
  });

  group('Pruebas de Entrega de Actividades', () {
    testWidgets('Realizar una entrega de actividad exitosa como alumno',
        (WidgetTester tester) async {
      // 1. Configurar el mock de AuthProvider (como alumno)
      final userModel = UserModel(
        id: '1',
        nombre: 'Estudiante',
        apellidos: 'Test',
        email: 'estudiante@example.com',
        tipoUsuario: 'Alumno',
      );
      
      when(mockAuthProvider.currentUser).thenReturn(userModel);
      when(mockAuthProvider.token).thenReturn('token-test');
      when(mockAuthProvider.isAuthenticated).thenReturn(true);
      
      // 2. Configurar el mock de ActivityService para devolver una actividad
      final mockActivity = ActivityModel(
        id: 1,
        titulo: 'Ejercicio de bucles',
        descripcion: 'Crear algoritmos utilizando bucles while y for',
        fechaCreacion: DateTime.now().subtract(const Duration(days: 2)),
        fechaEntrega: DateTime.now().add(const Duration(days: 5)),
        asignaturaId: 1,
        lenguajeProgramacion: 'Python',
      );
      
      when(mockActivityService.getActivity(any, any))
          .thenAnswer((_) async => mockActivity);
      
      // 3. Configurar respuesta para comprobar si ya existe una entrega (devolver null para simular primera entrega)
      when(mockSubmissionService.getStudentSubmission2(any, any, any))
          .thenThrow(Exception('404'));
      
      // 4. Configurar respuesta para la creación de una nueva entrega
      final mockSubmission = Submission(
        id: 1,
        fechaEntrega: DateTime.now(),
        actividadId: 1,
        alumnoId: 1,
        textoOcr: 'Esta es mi solución al problema de bucles',
      );
      
      when(mockSubmissionService.submitActivity(any, any, any, image: null))
          .thenAnswer((_) async => mockSubmission);
      
      // 5. Construir el widget con un sistema más controlado
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(
                value: mockAuthProvider,
              ),
              ChangeNotifierProvider<ActivityProvider>(
                create: (_) => ActivityProvider(mockActivityService),
              ),
              ChangeNotifierProvider<SubmissionProvider>(
                create: (_) => SubmissionProvider(mockSubmissionService),
              ),
            ],
            builder: (context, child) {
              return MaterialApp(
                home: Navigator(
                  onGenerateRoute: (settings) {
                    if (settings.name == '/') {
                      return MaterialPageRoute(
                        builder: (context) => const StudentActivitySubmissionPage(),
                        settings: RouteSettings(
                          arguments: {'activityId': 1},
                        ),
                      );
                    }
                    return null;
                  },
                ),
              );
            },
          ),
        ),
      );
      
      // 6. Esperar a que se cargue la página
      await tester.pumpAndSettle(const Duration(seconds: 3));
      
      // 7. Verificar que se muestra la información de la actividad
      expect(find.text('Ejercicio de bucles'), findsOneWidget);
      
      // 8. Verificar que se muestra el formulario de entrega
      expect(find.text('Tu solución'), findsOneWidget);
      
      // 9. Ingresar texto en el campo de solución
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Escribe tu solución aquí...'), 
        'Esta es mi solución al problema de bucles'
      );
      await tester.pump();
      
      // 10. Pulsar el botón de entregar
      await tester.tap(find.text('Entregar'));
      await tester.pumpAndSettle();
      
      // 11. Verificar que se llamó al método submitActivity con los parámetros correctos
      verify(mockSubmissionService.submitActivity(
        1, // ID de la actividad
        'Esta es mi solución al problema de bucles', // Solución ingresada
        'token-test', // Token
        image: null, // Sin imagen
      )).called(1);
    });
    
    testWidgets('Visualizar una entrega existente',
        (WidgetTester tester) async {
      // 1. Configurar el mock de AuthProvider (como alumno)
      final userModel = UserModel(
        id: '1',
        nombre: 'Estudiante',
        apellidos: 'Test',
        email: 'estudiante@example.com',
        tipoUsuario: 'Alumno',
      );
      
      when(mockAuthProvider.currentUser).thenReturn(userModel);
      when(mockAuthProvider.token).thenReturn('token-test');
      when(mockAuthProvider.isAuthenticated).thenReturn(true);
      
      // 2. Configurar el mock de ActivityService para devolver una actividad
      final mockActivity = ActivityModel(
        id: 1,
        titulo: 'Ejercicio de bucles',
        descripcion: 'Crear algoritmos utilizando bucles while y for',
        fechaCreacion: DateTime.now().subtract(const Duration(days: 2)),
        fechaEntrega: DateTime.now().add(const Duration(days: 5)),
        asignaturaId: 1,
        lenguajeProgramacion: 'Python',
      );
      
      when(mockActivityService.getActivity(any, any))
          .thenAnswer((_) async => mockActivity);
      
      // 3. Configurar respuesta para simular una entrega existente
      final mockSubmission = Submission(
        id: 1,
        fechaEntrega: DateTime.now().subtract(const Duration(hours: 2)),
        actividadId: 1,
        alumnoId: 1,
        textoOcr: 'Esta es mi solución al problema de bucles',
      );
      
      when(mockSubmissionService.getStudentSubmission2(any, any, any))
          .thenAnswer((_) async => mockSubmission);
      
      // 4. Construir el widget
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(
                value: mockAuthProvider,
              ),
              ChangeNotifierProvider<ActivityProvider>(
                create: (_) => ActivityProvider(mockActivityService),
              ),
              ChangeNotifierProvider<SubmissionProvider>(
                create: (_) => SubmissionProvider(mockSubmissionService),
              ),
            ],
            builder: (context, child) {
              return MaterialApp(
                home: Navigator(
                  onGenerateRoute: (settings) {
                    if (settings.name == '/') {
                      return MaterialPageRoute(
                        builder: (context) => const StudentActivitySubmissionPage(),
                        settings: RouteSettings(
                          arguments: {'activityId': 1},
                        ),
                      );
                    }
                    return null;
                  },
                ),
              );
            },
          ),
        ),
      );
      
      // 5. Esperar a que se cargue la página
      await tester.pumpAndSettle(const Duration(seconds: 3));
      
      // 6. Verificar que se muestra la información de la actividad
      expect(find.text('Ejercicio de bucles'), findsOneWidget);
      
      // 7. Verificar que se muestra la entrega existente
      expect(find.text('Tu entrega'), findsOneWidget);
      expect(find.text('Esta es mi solución al problema de bucles'), findsOneWidget);
      
      // 8. Verificar que no se muestra el formulario de nueva entrega
      expect(find.text('Tu solución'), findsNothing);
    });
  });
} 