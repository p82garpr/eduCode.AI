import 'package:flutter_test/flutter_test.dart';
import 'package:educode/core/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ThemeProvider', () {
    late ThemeProvider themeProvider;

    setUp(() async {
      // Configurar SharedPreferences para testing
      SharedPreferences.setMockInitialValues({});
      themeProvider = ThemeProvider();
      // Esperar a que se carguen las preferencias
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('inicializa con el tema claro por defecto', () {
      // Verificar que inicialmente el tema es claro
      expect(themeProvider.isDarkMode, isFalse);
    });

    test('cambia a tema oscuro al hacer toggle', () async {
      // Estado inicial: tema claro
      expect(themeProvider.isDarkMode, isFalse);
      
      // Cambiar a tema oscuro
      themeProvider.toggleTheme();
      
      // Verificar que ahora el tema es oscuro
      expect(themeProvider.isDarkMode, isTrue);
    });

    test('cambia a tema claro al hacer toggle desde tema oscuro', () async {
      // Cambiar primero a tema oscuro
      themeProvider.toggleTheme();
      expect(themeProvider.isDarkMode, isTrue);
      
      // Cambiar de nuevo a tema claro
      themeProvider.toggleTheme();
      
      // Verificar que ahora el tema es claro
      expect(themeProvider.isDarkMode, isFalse);
    });

    test('persiste el valor del tema en SharedPreferences', () async {
      // Configurar SharedPreferences para testing con valores iniciales
      SharedPreferences.setMockInitialValues({"theme": true});
      
      // Crear una nueva instancia que debería cargar el valor desde prefs
      final newProvider = ThemeProvider();
      
      // Esperar a que se carguen las preferencias
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Verificar que el tema se cargó como oscuro desde SharedPreferences
      expect(newProvider.isDarkMode, isTrue);
    });
  });
} 