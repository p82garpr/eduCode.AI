import 'package:educode/core/providers/theme_provider.dart';
import 'package:educode/core/services/secure_storage_service.dart';
import 'package:educode/features/courses/data/services/activity_service.dart';
import 'package:educode/features/courses/data/services/enrollment_service.dart';
import 'package:educode/features/courses/data/services/submission_service.dart';
import 'package:educode/features/courses/presentation/providers/activity_provider.dart';
import 'package:educode/features/courses/presentation/providers/enrollment_provider.dart';
import 'package:educode/features/courses/presentation/providers/submission_provider.dart';
import 'package:educode/features/courses/presentation/views/student_activity_submission_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/courses/presentation/providers/subjects_provider.dart';
import 'features/courses/data/services/subjects_service.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/password_reset_page.dart';
import 'features/courses/presentation/pages/home_page.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/services/auth_service.dart';

void main() {
  // Asegurarse de que Flutter está inicializado
  WidgetsFlutterBinding.ensureInitialized();
  
  // Iniciar la app después de la inicialización
  initApp();
}

// Variable global para el NavigatorKey
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> initApp() async {
  // Inicializar SharedPreferences
  await SharedPreferences.getInstance();

  // Crear instancia del SecureStorageService
  final secureStorage = SecureStorageService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            AuthService(),
            secureStorage,
          ),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (context) => SubjectsProvider(SubjectsService()),
        ),
        ChangeNotifierProvider(
          create: (context) => EnrollmentProvider(EnrollmentService()),
        ),
        ChangeNotifierProvider(
          create: (context) => SubmissionProvider(SubmissionService()),
        ),
        ChangeNotifierProvider(
          create: (context) => ActivityProvider(ActivityService()),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    initAppLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> initAppLinks() async {
    _appLinks = AppLinks();

    // Gestionar los enlaces que abren la aplicación
    final appLink = await _appLinks.getInitialAppLink();
    if (appLink != null) {
      _handleAppLink(appLink);
    }

    // Escuchar los enlaces que recibe la app cuando ya está en ejecución
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleAppLink(uri);
    });
  }

  void _handleAppLink(Uri uri) {
    debugPrint('Deep link recibido: $uri');
    
    // Verificar si es para restablecimiento de contraseña
    // Posibles formatos:
    // - educode://reset-password?token=XXX
    // - educode://reset-password/?token=XXX
    if (uri.path == '/reset-password' || 
        uri.path == 'reset-password' ||
        uri.path.isEmpty && uri.host == 'reset-password') {
      
      // Extraer token
      final token = uri.queryParameters['token'];
      if (token != null) {
        debugPrint('Token recibido: $token');
        
        // Navegar a la página de restablecimiento con el token
        Future.delayed(const Duration(milliseconds: 100), () {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => PasswordResetPage(initialToken: token),
            ),
          );
        });
      } else {
        debugPrint('No se encontró token en la URL: $uri');
      }
    } else {
      debugPrint('Link no reconocido. Path: ${uri.path}, Host: ${uri.host}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'EduCode',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: FutureBuilder(
            future: Provider.of<AuthProvider>(context, listen: false).checkAuthStatus(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final isAuthenticated = snapshot.data ?? false;
              return isAuthenticated ? const HomePage() : const LoginPage();
            },
          ),
          routes: {
            '/login': (context) => const LoginPage(),
            '/home': (context) => const HomePage(),
            '/reset-password': (context) => const PasswordResetPage(),
            '/student-activity-submission': (context) => const StudentActivitySubmissionPage(),
          },
        );
      },
    );
  }
}
