import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../../core/config/app_config.dart';
import '../../../../core/network/http_client.dart';

import '../../domain/models/user_profile_model.dart';

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

      if (response.statusCode != 200) {
        final error = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(error['detail'] ?? 'Error al obtener el perfil: ${response.statusCode}');
      }

      return UserProfileModel.fromJson(json.decode(utf8.decode(response.bodyBytes)));
    } catch (e) {
      debugPrint('Error en SubjectsService.getUserProfile: $e');
      rethrow;
    }
  }
} 