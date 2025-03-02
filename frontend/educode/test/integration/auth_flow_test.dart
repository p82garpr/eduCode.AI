import 'package:educode/features/auth/domain/models/user_model.dart';
import 'package:educode/features/auth/data/services/auth_service.dart';
import 'package:educode/features/auth/presentation/pages/login_page.dart';
import 'package:educode/features/auth/presentation/providers/auth_provider.dart';
import 'package:educode/features/auth/presentation/widgets/auth_button.dart';
import 'package:educode/core/services/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'auth_flow_test.mocks.dart';

// Crear un widget personalizado para pruebas de login
class TestLoginPage extends StatelessWidget {
  const TestLoginPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 50),
              const Text(
                'Bienvenido a EduCode',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Inicia sesión para continuar',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: AuthButton(
                  text: 'Iniciar Sesión',
                  onPressed: () async {
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    try {
                      await authProvider.login(
                        'test@example.com',
                        'password123',
                      );
                      // No navegamos en la prueba
                    } catch (e) {
                      // Manejar error
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Crear un widget personalizado para pruebas de registro
class TestRegisterPage extends StatelessWidget {
  const TestRegisterPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 50),
              const Text(
                'Crea tu cuenta en EduCode',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Regístrate para comenzar a aprender',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 30),
              const TextField(
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Apellidos',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              const TextField(
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: AuthButton(
                  text: 'Registrarse',
                  onPressed: () async {
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    try {
                      await authProvider.register(
                        'test@example.com',
                        'password123',
                        'Test',
                        'User',
                      );
                      // No navegamos en la prueba
                    } catch (e) {
                      // Manejar error
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

@GenerateMocks([AuthService, SecureStorageService])
void main() {
  late MockAuthService mockAuthService;
  late MockSecureStorageService mockSecureStorageService;

  setUp(() {
    mockAuthService = MockAuthService();
    mockSecureStorageService = MockSecureStorageService();
    
    // Desactivar animaciones para evitar problemas de timers
    TestWidgetsFlutterBinding.ensureInitialized();
    final binding = TestWidgetsFlutterBinding.instance;
    binding.window.devicePixelRatioTestValue = 1.0;
    binding.window.physicalSizeTestValue = const Size(1080, 2400);
  });

  // Grupo de pruebas para el login
  group('Pruebas de Login', () {
    testWidgets('Verificar que el servicio de autenticación es llamado con las credenciales correctas', 
        (WidgetTester tester) async {
      // Configurar mocks
      when(mockAuthService.login(any, any))
          .thenAnswer((_) async => 'token-test');
      
      when(mockSecureStorageService.saveToken(any)).thenAnswer((_) async {});
      when(mockSecureStorageService.saveUserInfo(
        id: anyNamed('id'),
        type: anyNamed('type'),
        name: anyNamed('name'),
        email: anyNamed('email'),
        lastName: anyNamed('lastName'),
      )).thenAnswer((_) async {});
      
      when(mockAuthService.getUserInfo(any)).thenAnswer((_) async => UserModel(
        id: '1',
        nombre: 'Test',
        apellidos: 'User',
        email: 'test@example.com',
        tipoUsuario: 'Estudiante',
      ));
      
      // Construir el widget con los providers necesarios
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(mockAuthService, mockSecureStorageService),
            child: const TestLoginPage(),
          ),
        ),
      );
      
      // Pulsar botón de login
      await tester.tap(find.byType(AuthButton));
      await tester.pump(const Duration(milliseconds: 100));
      
      // Verificar que se llamó al método login con los parámetros correctos
      verify(mockAuthService.login('test@example.com', 'password123')).called(1);
      
      // Verificar que se guardó el token
      verify(mockSecureStorageService.saveToken('token-test')).called(1);
      
      // Verificar que se guardó la información del usuario
      verify(mockSecureStorageService.saveUserInfo(
        id: '1',
        type: 'Estudiante',
        name: 'Test',
        email: 'test@example.com',
        lastName: 'User',
      )).called(1);
    });
    
    testWidgets('Verificar manejo de errores en el login', 
        (WidgetTester tester) async {
      // Configurar mocks para simular un error
      when(mockAuthService.login(any, any))
          .thenThrow(Exception('Credenciales inválidas'));
      
      // Construir el widget con los providers necesarios
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(mockAuthService, mockSecureStorageService),
            child: const TestLoginPage(),
          ),
        ),
      );
      
      // Pulsar botón de login
      await tester.tap(find.byType(AuthButton));
      await tester.pump(const Duration(milliseconds: 100));
      
      // Verificar que se llamó al método login con los parámetros correctos
      verify(mockAuthService.login('test@example.com', 'password123')).called(1);
      
      // Verificar que NO se guardó ningún token
      verifyNever(mockSecureStorageService.saveToken(any));
      
      // Verificar que NO se guardó información del usuario
      verifyNever(mockSecureStorageService.saveUserInfo(
        id: anyNamed('id'),
        type: anyNamed('type'),
        name: anyNamed('name'),
        email: anyNamed('email'),
        lastName: anyNamed('lastName'),
      ));
      
      // Verificar que el error se estableció en el provider
      final authProvider = Provider.of<AuthProvider>(
        tester.element(find.byType(TestLoginPage)),
        listen: false,
      );
      expect(authProvider.error, contains('Credenciales inválidas'));
      expect(authProvider.isAuthenticated, false);
    });
  });
  
  // Grupo de pruebas para el registro
  group('Pruebas de Registro', () {
    testWidgets('Verificar que el servicio de registro es llamado con los datos correctos', 
        (WidgetTester tester) async {
      // Configurar mocks
      when(mockAuthService.register(
        'Test',
        'User',
        'test@example.com',
        'password123',
      )).thenAnswer((_) async => UserModel(
        id: '1',
        nombre: 'Test',
        apellidos: 'User',
        email: 'test@example.com',
        tipoUsuario: 'Estudiante',
      ));
      
      // Configurar login que se llama después del registro
      when(mockAuthService.login(any, any))
          .thenAnswer((_) async => 'token-test');
      
      when(mockAuthService.getUserInfo(any)).thenAnswer((_) async => UserModel(
        id: '1',
        nombre: 'Test',
        apellidos: 'User',
        email: 'test@example.com',
        tipoUsuario: 'Estudiante',
      ));
      
      when(mockSecureStorageService.saveToken(any)).thenAnswer((_) async {});
      when(mockSecureStorageService.saveUserInfo(
        id: anyNamed('id'),
        type: anyNamed('type'),
        name: anyNamed('name'),
        email: anyNamed('email'),
        lastName: anyNamed('lastName'),
      )).thenAnswer((_) async {});
      
      // Construir el widget con los providers necesarios
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(mockAuthService, mockSecureStorageService),
            child: const TestRegisterPage(),
          ),
        ),
      );
      
      // Pulsar botón de registro
      await tester.tap(find.byType(AuthButton));
      await tester.pump(const Duration(milliseconds: 100));
      
      // Verificar que se llamó a AuthService.register con los parámetros en el orden correcto
      verify(mockAuthService.register(
        'Test',
        'User',
        'test@example.com',
        'password123',
      )).called(1);
      
      // Verificar que también se llamó al login después del registro
      verify(mockAuthService.login('test@example.com', 'password123')).called(1);
      
      // Verificar que se guardó el token
      verify(mockSecureStorageService.saveToken('token-test')).called(1);
      
      // Verificar que se guardó la información del usuario
      verify(mockSecureStorageService.saveUserInfo(
        id: '1',
        type: 'Estudiante',
        name: 'Test',
        email: 'test@example.com',
        lastName: 'User',
      )).called(1);
    });
    
    testWidgets('Verificar manejo de errores en el registro', 
        (WidgetTester tester) async {
      // Configurar mocks para simular un error
      when(mockAuthService.register(
        'Test',
        'User',
        'test@example.com',
        'password123',
      )).thenThrow(Exception('El email ya está registrado'));
      
      // Construir el widget con los providers necesarios
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(mockAuthService, mockSecureStorageService),
            child: const TestRegisterPage(),
          ),
        ),
      );
      
      // Pulsar botón de registro
      await tester.tap(find.byType(AuthButton));
      await tester.pump(const Duration(milliseconds: 100));
      
      // Verificar que se llamó al método register con los parámetros correctos
      verify(mockAuthService.register(
        'Test',
        'User',
        'test@example.com',
        'password123',
      )).called(1);
      
      // Verificar que NO se guardó información del usuario
      verifyNever(mockSecureStorageService.saveUserInfo(
        id: anyNamed('id'),
        type: anyNamed('type'),
        name: anyNamed('name'),
        email: anyNamed('email'),
        lastName: anyNamed('lastName'),
      ));
      
      // Verificar que el error se estableció en el provider
      final authProvider = Provider.of<AuthProvider>(
        tester.element(find.byType(TestRegisterPage)),
        listen: false,
      );
      expect(authProvider.error, contains('El email ya está registrado'));
      expect(authProvider.isAuthenticated, false);
    });
  });
} 