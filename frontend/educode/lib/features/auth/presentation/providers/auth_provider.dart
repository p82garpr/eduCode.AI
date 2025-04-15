import '../../data/services/auth_service.dart';
import '../../domain/models/user_model.dart';
import 'package:flutter/material.dart';
import '../../../../core/services/secure_storage_service.dart';


class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final SecureStorageService _secureStorage;
  UserModel? _currentUser;
  String? _token;
  bool _isLoading = false;
  String? _error;
  int _retryAttempts = 0;
  static const int maxRetryAttempts = 3;

  AuthProvider(this._authService, this._secureStorage);

  // Getters
  UserModel? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null && _token != null;

  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _token = await _authService.login(email, password);
      if (_token == null) {
        throw AuthException('No se pudo obtener el token de autenticación');
      }

      _currentUser = await _getUserInfoWithRetry(_token!);

      // Guardar información en el almacenamiento seguro
      await _secureStorage.saveToken(_token!);
      await _secureStorage.saveUserInfo(
        id: _currentUser!.id.toString(),
        type: _currentUser!.tipoUsuario,
        name: _currentUser!.nombre,
        email: _currentUser!.email,
        lastName: _currentUser!.apellidos,
      );

      _isLoading = false;
      _retryAttempts = 0;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    _token = null;
    _retryAttempts = 0;
    await _secureStorage.clearAll();
    notifyListeners();
  }

  Future<bool> checkAuthStatus() async {
    try {
      final token = await _secureStorage.getToken();

      if (token == null) {
        return false;
      }

      try {
        _token = token;
        _currentUser = await _getUserInfoWithRetry(token);
        
        notifyListeners();
        return true;
      } catch (e) {
        // Solo limpiar si el error es de autenticación
        if (e is AuthException && 
            (e.toString().contains('401') || e.toString().contains('no autorizado'))) {
          await _handleAuthError();
          return false;
        }
        
        // Si es error de conexión, mantener el token y reintentar después
        _error = e.toString();
        notifyListeners();
        return false;
      }
    } catch (e) {
      await _handleAuthError();
      return false;
    }
  }

  Future<UserModel> _getUserInfoWithRetry(String token) async {
    while (_retryAttempts < maxRetryAttempts) {
      try {
        final user = await _authService.getUserInfo(token);
        _retryAttempts = 0;
        return user;
      } catch (e) {
        _retryAttempts++;
        if (_retryAttempts >= maxRetryAttempts) {
          rethrow;
        }
        await Future.delayed(Duration(seconds: _retryAttempts));
      }
    }
    throw AuthException('No se pudo obtener la información del usuario después de varios intentos');
  }

  Future<void> _handleAuthError() async {
    _token = null;
    _currentUser = null;
    await _secureStorage.clearAll();
    _retryAttempts = 0;
    notifyListeners();
  }

  Future<bool> register(String email, String password, String name, String lastName, String userType) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Registrar al usuario
      // ignore: unused_local_variable, no_leading_underscores_for_local_identifiers
      final _currentUser = await _authService.register(name, lastName, email, password, userType);

      // Si el registro es exitoso, iniciar sesión automáticamente
      final loginSuccess = await login(email, password);
      
      if (!loginSuccess) {
        throw Exception('Error al iniciar sesión automáticamente');
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      // Manejar específicamente el error de correo duplicado
      if (e.toString().contains('400')) {
        _error = 'El correo ya esta registrado';
      } else {
        _error = e.toString().replaceAll('Exception:', '');
      }
      
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> updateProfile({
    required String nombre,
    required String apellidos,
    required String email,
    String? password,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final updatedUser = await _authService.updateProfile(
        nombre: nombre,
        apellidos: apellidos,
        email: email,
        password: password,
        token: _token!,
      );

      // Actualizamos el usuario actual con los nuevos datos
      _currentUser = updatedUser;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
} 