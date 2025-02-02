import 'package:flutter/foundation.dart';
import '../../data/services/auth_service.dart';
import '../../domain/models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  bool _isLoading = false;
  String? _error;
  UserModel? _currentUser;

  bool get isLoading => _isLoading;
  String? get error => _error;
  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _currentUser = await _authService.login(email, password);
      
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

  Future<bool> register(String email, String password, String name, String lastName) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _currentUser = await _authService.register(name, lastName, email, password);

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

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
} 