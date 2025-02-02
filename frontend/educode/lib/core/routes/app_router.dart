import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isAuthenticated = authProvider.isAuthenticated;
    final path = state.uri.path;

    if (isAuthenticated && (path == '/login' || path == '/register')) {
      return '/home';
    }

    if (!isAuthenticated && path != '/login' && path != '/register') {
      return '/login';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),
  ],
); 