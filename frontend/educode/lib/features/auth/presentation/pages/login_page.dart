import 'package:educode/features/auth/presentation/pages/register_page.dart';
import 'package:educode/features/courses/presentation/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/auth_button.dart';
import 'package:animate_do/animate_do.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          height: size.height,
          width: size.width,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.primary.withOpacity(0.1),
                colors.secondary.withOpacity(0.1),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 30),
                FadeInDown(
                  duration: const Duration(milliseconds: 800),
                  child: Image.asset(
                    'assets/images/epsc-logo.png',
                    height: 300
                  ),
                ),
                const SizedBox(height: 40),
                FadeInDown(
                  delay: const Duration(milliseconds: 200),
                  duration: const Duration(milliseconds: 800),
                  child: Text(
                    'Bienvenido a EduCode',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                  ),
                ),
                const SizedBox(height: 10),
                FadeInDown(
                  delay: const Duration(milliseconds: 400),
                  duration: const Duration(milliseconds: 800),
                  child: Text(
                    'Inicia sesión para continuar',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colors.onSurface.withOpacity(0.7),
                        ),
                  ),
                ),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        FadeInDown(
                          delay: const Duration(milliseconds: 600),
                          duration: const Duration(milliseconds: 800),
                          child: CustomTextField(
                            controller: _emailController,
                            label: 'Email',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value?.isEmpty ?? true) {
                                return 'Por favor ingrese su email';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        FadeInDown(
                          delay: const Duration(milliseconds: 800),
                          duration: const Duration(milliseconds: 800),
                          child: CustomTextField(
                            controller: _passwordController,
                            label: 'Contraseña',
                            prefixIcon: Icons.lock_outline,
                            obscureText: true,
                            validator: (value) {
                              if (value?.isEmpty ?? true) {
                                return 'Por favor ingrese su contraseña';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        Consumer<AuthProvider>(
                          builder: (context, auth, _) {
                            if (auth.error != null) {
                              return FadeIn(
                                child: Text(
                                  auth.error!,
                                  style: TextStyle(color: colors.error),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                        const SizedBox(height: 30),
                        FadeInDown(
                          delay: const Duration(milliseconds: 1000),
                          duration: const Duration(milliseconds: 800),
                          child: AuthButton(
                            text: 'Iniciar Sesión',
                            onPressed: _handleLogin,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FadeInDown(
                          delay: const Duration(milliseconds: 1200),
                          duration: const Duration(milliseconds: 800),
                          child: TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterPage(),
                              ),
                            ),
                            child: Text(
                              '¿No tienes cuenta? Regístrate',
                              style: TextStyle(color: colors.primary),
                            ),
                          ),

                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      final success = await context.read<AuthProvider>().login(
        _emailController.text,
        _passwordController.text,
      );

      if (success && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const HomePage(),
            maintainState: false,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
} 