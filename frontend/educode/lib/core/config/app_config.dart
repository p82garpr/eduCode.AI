class AppConfig {
  // URLs
  static const String apiBaseUrl = 'http://10.0.2.2:8000/api/v1';
  
  // Para probar con diferentes configuraciones, descomenta una de estas opciones:
  //static const String apiBaseUrl = 'http://192.168.1.170:8000/api/v1'; // IP específica de tu máquina
  //static const String apiBaseUrl = 'http://10.0.3.2:8000/api/v1'; // Genymotion
  //static const String apiBaseUrl = 'http://localhost:8000/api/v1'; // Algunos emuladores
  //static const String apiBaseUrl = 'http://127.0.0.1:8000/api/v1'; // Localhost IP

  
  // Versiones
  static const String appVersion = '1.0.0';
  
  // Timeouts
  static const int connectionTimeout = 30000; // 30 segundos
  
  // Otros valores globales que puedas necesitar
  static const int maxRetries = 3;
  static const bool isDevelopment = true;
} 