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

  AuthProvider(this._authService, this._secureStorage);

  // Getters
  UserModel? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _token = await _authService.login(email, password);
      _currentUser = await _authService.getUserInfo(_token!);

      // Guardar en almacenamiento seguro
      await _secureStorage.saveToken(_token!);
      await _secureStorage.saveUserInfo(
        id: _currentUser!.id.toString(),
        type: _currentUser!.tipoUsuario,
        name: _currentUser!.nombre,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    _token = null;
    await _secureStorage.clearAll();
    notifyListeners();
  }

  // Método para verificar si hay una sesión guardada al iniciar la app
  Future<bool> checkAuthStatus() async {
    final token = await _secureStorage.getToken();
    if (token != null) {
      _token = token;
      final userInfo = await _secureStorage.getUserInfo();
      // Aquí podrías hacer una llamada al backend para obtener los datos actualizados del usuario
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> register(String email, String password, String name, String lastName) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Registrar al usuario
      // ignore: unused_local_variable, no_leading_underscores_for_local_identifiers
      final _currentUser = await _authService.register(name, lastName, email, password);

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