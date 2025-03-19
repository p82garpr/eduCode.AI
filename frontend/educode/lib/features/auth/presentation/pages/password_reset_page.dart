import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_text_field.dart';
import '../../../../core/config/app_config.dart';
import '../../data/services/auth_service.dart';

class PasswordResetPage extends StatefulWidget {
  final String? initialToken;
  
  const PasswordResetPage({this.initialToken, super.key});

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _emailSent = false;
  String? _token;
  String? _error;
  String? _email;

  // Si el token está en la URL (web), extraerlo al inicio
  @override
  void initState() {
    super.initState();
    // Si hay un token inicial, configurar el estado
    if (widget.initialToken != null && widget.initialToken!.isNotEmpty) {
      setState(() {
        _token = widget.initialToken;
        _emailSent = true; // Fingimos que el email ya fue enviado
      });
    }
  }

  Future<void> _requestPasswordReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final message = await _authService.requestPasswordReset(_emailController.text);
      
      if (!mounted) return;

      setState(() {
        _emailSent = true;
        _email = _emailController.text;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyTokenAndReset() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Verificamos primero que el token sea válido
      if (_token != null && _token!.isNotEmpty) {
        await _authService.verifyResetToken(_token!);
        
        // Si es válido, procedemos a cambiar la contraseña
        final message = await _authService.resetPassword(
          _token!,
          _passwordController.text,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        Navigator.pop(context); // Volver a login
      } else {
        setState(() => _error = 'Por favor, introduce un token válido');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuperar contraseña'),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo o icono
                  Icon(
                    Icons.lock_reset,
                    size: 64,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 32),

                  // Título explicativo según la etapa
                  Text(
                    _emailSent && _token == null
                        ? 'Correo enviado'
                        : _token != null
                            ? 'Establece tu nueva contraseña'
                            : 'Recupera tu contraseña',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  // Instrucciones según la etapa
                  Text(
                    _emailSent && _token == null
                        ? 'Te hemos enviado un correo con instrucciones para restablecer tu contraseña. Por favor, haz clic en el enlace del correo.'
                        : _token != null
                            ? 'Introduce tu nueva contraseña'
                            : 'Introduce tu correo electrónico y te enviaremos instrucciones para restablecer tu contraseña.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Mensaje de error
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(color: colors.onErrorContainer),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Primera etapa: Solicitar restablecimiento
                  if (!_emailSent) ...[
                    CustomTextField(
                      controller: _emailController,
                      label: 'Email',
                      prefixIcon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, introduce tu email';
                        }
                        if (!value.contains('@')) {
                          return 'Por favor, introduce un email válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _requestPasswordReset,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send),
                      label: Text(_isLoading ? 'Enviando...' : 'Enviar instrucciones'),
                    ),
                  ]
                  // Segunda etapa: Email enviado, esperar a que use el link
                  else if (_token == null) ...[
                    Text(
                      'Si no recibes el correo en unos minutos, revisa tu carpeta de spam o intenta de nuevo.',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Si tienes un código de recuperación, puedes ingresarlo directamente:',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.visible,
                    ),
                    const SizedBox(height: 16),
                    // Campo para ingresar token manualmente (para pruebas o si el enlace no funciona)
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Código de recuperación',
                        hintText: 'Ingresa el código que recibiste en tu correo',
                        prefixIcon: const Icon(Icons.key),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                      onChanged: (value) {
                        setState(() => _token = value);
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _emailSent = false;
                                _token = null;
                              });
                            },
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Volver'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _token != null && _token!.isNotEmpty
                                ? () {
                                    // Avanzar a la siguiente etapa
                                    setState(() {});
                                  }
                                : null,
                            icon: const Icon(Icons.check),
                            label: const Text('Continuar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.primary,
                              foregroundColor: colors.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ]
                  // Tercera etapa: Ingresar nueva contraseña
                  else ...[
                    CustomTextField(
                      controller: _passwordController,
                      label: 'Nueva contraseña',
                      prefixIcon: Icons.lock,
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, introduce tu nueva contraseña';
                        }
                        if (value.length < 6) {
                          return 'La contraseña debe tener al menos 6 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirmar contraseña',
                      prefixIcon: Icons.lock_outline,
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, confirma tu contraseña';
                        }
                        if (value != _passwordController.text) {
                          return 'Las contraseñas no coinciden';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _verifyTokenAndReset,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: Text(_isLoading ? 'Procesando...' : 'Cambiar contraseña'),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // Enlace para volver al login
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Volver al inicio de sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
} 