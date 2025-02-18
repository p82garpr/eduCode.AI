
import 'package:educode/features/courses/data/services/profile_service.dart';
import 'package:educode/features/courses/domain/models/user_profile_model.dart';
import 'package:flutter/material.dart';

class ProfileProvider extends ChangeNotifier {
  final ProfileService _profileService;

  ProfileProvider({required ProfileService profileService}) : _profileService = profileService;
  
  Future<UserProfileModel> getUserProfile(String userId, String token) async {
    try {
      return await _profileService.getUserProfile(userId, token);
    } catch (e) {
      debugPrint('Error en ProfileProvider.getUserProfile: $e');
      rethrow;
    }
  }
} 

