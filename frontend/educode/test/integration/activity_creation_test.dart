import 'package:educode/features/auth/domain/models/user_model.dart';
import 'package:educode/features/auth/presentation/providers/auth_provider.dart';
import 'package:educode/features/courses/data/services/activity_service.dart';
import 'package:educode/features/courses/domain/models/activity_model.dart';
import 'package:educode/features/courses/domain/models/subject_model.dart';
import 'package:educode/features/courses/presentation/providers/activity_provider.dart';
import 'package:educode/features/courses/presentation/widgets/create_activity_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'activity_creation_test.mocks.dart';

// Clase de prueba para simular la creación exitosa de una actividad
class TestActivityCreationSuccessWidget extends StatelessWidget {
  final int subjectId;
  
  const TestActivityCreationSuccessWidget({
    Key? key, 
    required this.subjectId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => _createActivity(context),
          child: const Text('Crear Actividad'),
        ),
      ),
    );
  }

  Future<void> _createActivity(BuildContext context) async {
    // Simulamos la apertura del diálogo de creación de actividades
    final result = await CreateActivityDialog.show(context);
    
    if (result == null) return; // Usuario canceló
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final activityProvider = Provider.of<ActivityProvider>(context, listen: false);
    
    final token = authProvider.token;

    if (token == null) {
      print('Error: No hay sesión activa');
      return;
    }

    try {
      // Crear la actividad con los datos proporcionados
      await activityProvider.createActivity(
        subjectId,
        result,
        token,
      );
    } catch (e) {
      print('Error en provider: $e');
    }
  }
}

// Clase de prueba para simular un error durante la creación de una actividad
class TestActivityCreationErrorWidget extends StatelessWidget {
  final int subjectId;
  
  const TestActivityCreationErrorWidget({
    Key? key, 
    required this.subjectId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => _createActivity(context),
          child: const Text('Crear Actividad'),
        ),
      ),
    );
  }

  Future<void> _createActivity(BuildContext context) async {
    // Simulamos la apertura del diálogo de creación de actividades
    final result = await CreateActivityDialog.show(context);
    
    if (result == null) return; // Usuario canceló
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final activityProvider = Provider.of<ActivityProvider>(context, listen: false);
    
    final token = authProvider.token;

    if (token == null) {
      print('Error: No hay sesión activa');
      return;
    }

    try {
      // Crear la actividad con los datos proporcionados (fallará)
      await activityProvider.createActivity(
        subjectId,
        result,
        token,
      );
    } catch (e) {
      print('Error en provider: $e');
    }
  }
}

// Widget personalizado para simular el diálogo de creación de actividades sin problemas de RenderFlex
class MockCreateActivityDialog extends StatelessWidget {
  final void Function(Map<String, dynamic>?) onCompleted;

  const MockCreateActivityDialog({
    Key? key,
    required this.onCompleted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva actividad'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Título',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Descripción',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            DropdownButton<String>(
              isExpanded: true,
              value: 'Python',
              onChanged: (_) {},
              items: const [
                DropdownMenuItem(
                  value: 'Python',
                  child: Text('Python'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => onCompleted(null),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => onCompleted({
            'titulo': 'Ejercicio de bucles',
            'descripcion': 'Crear algoritmos utilizando bucles while y for',
            'fecha_entrega': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
            'lenguaje_programacion': 'Python',
          }),
          child: const Text('Crear'),
        ),
      ],
    );
  }
}

// Generar mocks para los servicios
@GenerateMocks([ActivityService, AuthProvider])
void main() {
  late MockActivityService mockActivityService;
  late MockAuthProvider mockAuthProvider;

  setUp(() {
    mockActivityService = MockActivityService();
    mockAuthProvider = MockAuthProvider();
    
    // Desactivar animaciones para evitar problemas de timers
    TestWidgetsFlutterBinding.ensureInitialized();
    final binding = TestWidgetsFlutterBinding.instance;
    binding.window.devicePixelRatioTestValue = 1.0;
    binding.window.physicalSizeTestValue = const Size(1200, 2400);
  });

  group('Pruebas de Creación de Actividades', () {
    testWidgets('Verificar que la creación de actividad funciona correctamente',
        (WidgetTester tester) async {
      // Configurar el mock de AuthProvider (como profesor)
      final userModel = UserModel(
        id: '1',
        nombre: 'Profesor',
        apellidos: 'Test',
        email: 'profesor@example.com',
        tipoUsuario: 'Profesor',
      );
      
      when(mockAuthProvider.currentUser).thenReturn(userModel);
      when(mockAuthProvider.token).thenReturn('token-test');
      when(mockAuthProvider.isAuthenticated).thenReturn(true);
      
      // Configurar respuesta del mock para la creación de actividad
      final mockActivity = ActivityModel(
        id: 1,
        titulo: 'Ejercicio de bucles',
        descripcion: 'Crear algoritmos utilizando bucles while y for',
        fechaCreacion: DateTime.now(),
        fechaEntrega: DateTime.now().add(const Duration(days: 7)),
        asignaturaId: 1,
        lenguajeProgramacion: 'Python',
      );
      
      when(mockActivityService.createActivity(any, any, any))
          .thenAnswer((_) async => mockActivity);
      
      // Usar un método más simple para probar la lógica sin problemas de UI
      bool dialogShown = false;
      bool createCalled = false;
      Map<String, dynamic>? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () async {
                    dialogShown = true;
                    // Simular el diálogo directamente
                    dialogResult = {
                      'titulo': 'Ejercicio de bucles',
                      'descripcion': 'Crear algoritmos utilizando bucles while y for',
                      'fecha_entrega': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
                      'lenguaje_programacion': 'Python',
                    };
                    
                    if (dialogResult != null) {
                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      final activityProvider = Provider.of<ActivityProvider>(context, listen: false);
                      final token = authProvider.token;
                      
                      if (token != null) {
                        try {
                          await activityProvider.createActivity(
                            1, // ID de la asignatura
                            dialogResult!,
                            token,
                          );
                          createCalled = true;
                        } catch (e) {
                          print('Error en provider: $e');
                        }
                      }
                    }
                  },
                  child: const Text('Crear Actividad'),
                );
              },
            ),
          ),
          builder: (context, child) {
            return MultiProvider(
              providers: [
                ChangeNotifierProvider<AuthProvider>.value(
                  value: mockAuthProvider,
                ),
                ChangeNotifierProvider<ActivityProvider>(
                  create: (_) => ActivityProvider(mockActivityService),
                ),
              ],
              child: child!,
            );
          },
        ),
      );
      
      // Pulsar botón de creación de actividad
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      
      // Verificar que se inició el proceso de creación
      expect(dialogShown, true);
      
      // Verificar que se llamó al método createActivity con los parámetros correctos
      verify(mockActivityService.createActivity(
        1, // ID de la asignatura
        argThat(
          predicate<Map<String, dynamic>>((data) => 
            data['titulo'] == 'Ejercicio de bucles' && 
            data['descripcion'] == 'Crear algoritmos utilizando bucles while y for' &&
            data['lenguaje_programacion'] == 'Python'
          )
        ),
        'token-test', // Token
      )).called(1);
    });
    
    testWidgets('Verificar manejo de errores durante la creación de actividad',
        (WidgetTester tester) async {
      // Configurar el mock de AuthProvider (como profesor)
      final userModel = UserModel(
        id: '1',
        nombre: 'Profesor',
        apellidos: 'Test',
        email: 'profesor@example.com',
        tipoUsuario: 'Profesor',
      );
      
      when(mockAuthProvider.currentUser).thenReturn(userModel);
      when(mockAuthProvider.token).thenReturn('token-test');
      when(mockAuthProvider.isAuthenticated).thenReturn(true);
      
      // Configurar el mock para simular un error
      when(mockActivityService.createActivity(any, any, any))
          .thenThrow(Exception('Error al crear la actividad'));
      
      // Usar un método más simple para probar la lógica sin problemas de UI
      bool exceptionCaught = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () async {
                    // Simular el diálogo directamente
                    final dialogResult = {
                      'titulo': 'Ejercicio con error',
                      'descripcion': 'Esta actividad generará un error',
                      'fecha_entrega': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
                    };
                    
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final activityProvider = Provider.of<ActivityProvider>(context, listen: false);
                    final token = authProvider.token;
                    
                    if (token != null) {
                      try {
                        await activityProvider.createActivity(
                          1, // ID de la asignatura
                          dialogResult,
                          token,
                        );
                      } catch (e) {
                        exceptionCaught = true;
                        print('Error en test: $e');
                      }
                    }
                  },
                  child: const Text('Crear Actividad con Error'),
                );
              },
            ),
          ),
          builder: (context, child) {
            return MultiProvider(
              providers: [
                ChangeNotifierProvider<AuthProvider>.value(
                  value: mockAuthProvider,
                ),
                ChangeNotifierProvider<ActivityProvider>(
                  create: (_) => ActivityProvider(mockActivityService),
                ),
              ],
              child: child!,
            );
          },
        ),
      );
      
      // Pulsar botón de creación de actividad
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      
      // Verificar que se llamó al método createActivity
      verify(mockActivityService.createActivity(any, any, any)).called(1);
      
      // Verificar que se capturó la excepción
      expect(exceptionCaught, true);
    });
  });
} 