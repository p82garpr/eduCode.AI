import 'package:flutter/foundation.dart';
import '../../data/services/enrollment_service.dart';
import '../../domain/models/enrolled_student_model.dart';
import '../../domain/models/user_profile_model.dart';

class EnrollmentProvider extends ChangeNotifier {
  final EnrollmentService _enrollmentService;
  bool _isLoading = false;
  String? _error;

  EnrollmentProvider(this._enrollmentService);

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<List<EnrolledStudent>> getEnrolledStudents(int subjectId, String token) async {
    try {
      _isLoading = true;
      Future.delayed(Duration.zero, notifyListeners);
      
      final students = await _enrollmentService.getEnrolledStudents(subjectId, token);
      
      _isLoading = false;
      notifyListeners();
      return students;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      throw Exception('Error al obtener los alumnos: ${e.toString()}');
    }
  }

  Future<void> enrollInSubject(String userId, String subjectId, String accessCode, String token) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _enrollmentService.enrollInSubject(userId, subjectId, accessCode, token);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('Error en EnrollmentProvider.enrollInSubject: $e');
      rethrow;
    }
  }

  Future<void> cancelEnrollment(int subjectId, int userId, String token) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _enrollmentService.cancelEnrollment(subjectId, userId, token);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('Error en EnrollmentProvider.cancelEnrollment: $e');
      rethrow;
    }
  }

  Future<void> removeStudentFromSubject(int subjectId, int studentId, String token) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _enrollmentService.cancelEnrollment(subjectId, studentId, token);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      throw Exception('Error al expulsar al alumno: ${e.toString()}');
    }
  }

  Future<UserProfileModel> getUserProfile(String userId, String token) async {
    try {
      _isLoading = true;
      notifyListeners();

      final profile = await _enrollmentService.getUserProfile(userId, token);
      
      _isLoading = false;
      notifyListeners();
      return profile;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('Error en EnrollmentProvider.getUserProfile: $e');
      rethrow;
    }
  }
} 