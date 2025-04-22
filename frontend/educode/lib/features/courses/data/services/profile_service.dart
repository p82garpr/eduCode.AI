import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/config/app_config.dart';
import '../../../../core/network/http_client.dart';

import '../../domain/models/user_profile_model.dart';

class ProfileException implements Exception {
  final String message;
  ProfileException(this.message);

  @override
  String toString() => message;
}

class ProfileService {
  final http.Client _client;
  final String _baseUrl = AppConfig.apiBaseUrl;

  ProfileService({http.Client? client})
      : _client = client ?? HttpClientFactory.createClient();

  Future<UserProfileModel> getUserProfile(String userId, String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/usuarios/$userId/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return UserProfileModel.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      } else if (response.statusCode == 404) {
        throw ProfileException('No se encontró el perfil del usuario');
      } else if (response.statusCode == 403) {
        throw ProfileException('No tienes permisos para ver este perfil');
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw ProfileException(error['detail'] ?? 'No pudimos obtener el perfil del usuario');
      }
    } catch (e) {
      if (e is ProfileException) rethrow;
      throw ProfileException('Error de conexión. Por favor, verifica tu internet');
    }
  }
} 