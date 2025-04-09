import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Crea un cliente HTTP que acepta certificados SSL autofirmados
class HttpClientFactory {
  /// Devuelve un cliente HTTP que acepta certificados SSL autofirmados
  static http.Client createClient() {
    final HttpClient httpClient = HttpClient()
      ..badCertificateCallback =
          ((X509Certificate cert, String host, int port) => true);
    
    return IOClient(httpClient);
  }
} 