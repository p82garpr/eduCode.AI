import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  bool _isAnimating = false;
  double _animationValue = 0.0;
  final String key = "theme";
  Timer? _animationTimer;

  bool get isDarkMode => _isDarkMode;
  bool get isAnimating => _isAnimating;
  double get animationValue => _animationValue;

  ThemeProvider() {
    _loadFromPrefs();
  }

  // Método para cambiar el tema con animación
  void toggleTheme() {
    if (_isAnimating) return; // Evitar múltiples cambios durante la animación
    
    _isAnimating = true;
    _animationValue = 0.0;
    notifyListeners();
    
    // Animación más rápida (solo 200ms)
    const duration = Duration(milliseconds: 200);
    
    // Cambiar inmediatamente el tema
    _isDarkMode = !_isDarkMode;
    _saveToPrefs();
    
    // Simular una animación más simple solo para el efecto visual
    Timer(const Duration(milliseconds: 50), () {
      _animationValue = 0.5;
      notifyListeners();
      
      Timer(const Duration(milliseconds: 150), () {
        _isAnimating = false;
        _animationValue = 0.0;
        notifyListeners();
      });
    });
  }

  // Cargar tema guardado de SharedPreferences
  Future<void> _loadFromPrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(key) ?? false;
    notifyListeners();
  }

  // Guardar tema en SharedPreferences
  Future<void> _saveToPrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool(key, _isDarkMode);
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }
} 