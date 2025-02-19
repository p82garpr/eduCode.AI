import '../../data/services/auth_service.dart';
import '../../domain/models/user_model.dart';
import 'package:flutter/material.dart';


class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  
  bool _isLoading = false;
  String? _error;
  UserModel? _currentUser;
  String? _token;

  AuthProvider(this._authService);

  bool get isLoading => _isLoading;
  String? get error => _error;
  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  String? get token => _token;

  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Primero obtenemos el token
      _token = await _authService.login(email, password);
      
      // Luego obtenemos la información del usuario
      if (_token != null) {
        _currentUser = await _authService.getUserInfo(_token!);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      throw Exception('No se pudo obtener el token');

    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      _token = null;
      _currentUser = null;
      notifyListeners();
      return false;
    }
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

  void logout() {
    _currentUser = null;
    _token = null;
    notifyListeners();
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