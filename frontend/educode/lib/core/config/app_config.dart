class AppConfig {
  // URLs
  static const String apiBaseUrl = 'http://10.0.2.2:8000/api/v1';
  //static const String apiBaseUrl = 'http://192.168.1.135:8000/api/v1';

  
  // Versiones
  static const String appVersion = '1.0.0';
  
  // Timeouts
  static const int connectionTimeout = 30000; // 30 segundos
  
  // Otros valores globales que puedas necesitar
  static const int maxRetries = 3;
  static const bool isDevelopment = true;
} 