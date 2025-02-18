import 'package:flutter/foundation.dart';
import 'dart:io';
import '../../data/services/submission_service.dart';
import '../../domain/models/submission_model.dart';

class SubmissionProvider extends ChangeNotifier {
  final SubmissionService _submissionService;
  bool _isLoading = false;
  String? _error;
  Submission? _currentSubmission;

  SubmissionProvider(this._submissionService);

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  Submission? get currentSubmission => _currentSubmission;

  Future<List<Submission>> getActivitySubmissions(int activityId, String token) async {
    try {
      _isLoading = true;
      Future.delayed(Duration.zero, notifyListeners);

      final submissions = await _submissionService.getActivitySubmissions(activityId, token);
      
      _isLoading = false;
      notifyListeners();
      return submissions;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      throw Exception('Error al obtener las entregas: ${e.toString()}');
    }
  }

  Future<void> gradeSubmission(int submissionId, double grade, String token) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _submissionService.gradeSubmission(submissionId, grade, token);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      throw Exception('Error al calificar la entrega: ${e.toString()}');
    }
  }

  Future<Submission?> getStudentSubmission(int activityId, String token) async {
    try {
      _isLoading = true;
      notifyListeners();

      final submission = await _submissionService.getStudentSubmission(activityId, token);
      _currentSubmission = submission;
      
      _isLoading = false;
      notifyListeners();
      return submission;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('Error en SubmissionProvider.getStudentSubmission: $e');
      rethrow;
    }
  }

  Future<Submission> submitActivity(int activityId, String solution, String token, {File? image}) async {
    try {
      _isLoading = true;
      notifyListeners();

      final submission = await _submissionService.submitActivity(activityId, solution, token, image: image);
      _currentSubmission = submission;
      
      _isLoading = false;
      notifyListeners();
      return submission;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Submission> getSubmissionDetails(int submissionId, String token) async {
    try {
      return await _submissionService.getSubmissionDetails(submissionId, token);
    } catch (e) {
      if (kDebugMode) {
        print('Error en getSubmissionDetails provider: $e');
      } // Debug
      rethrow;
    }
  }

  Future<Uint8List> getSubmissionImage(int submissionId, String token) async {
    try {
      _isLoading = true;
      notifyListeners();

      final imageData = await _submissionService.getSubmissionImage(submissionId, token);
      
      _isLoading = false;
      notifyListeners();
      return imageData;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('Error en getSubmissionImage provider: $e');
      rethrow;
    }
  }

  Future<void> evaluateSubmissionWithGemini(int submissionId, String token) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _submissionService.evaluateSubmissionWithGemini(submissionId, token);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('Error en SubmissionProvider.evaluateSubmissionWithGemini: $e');
      rethrow;
    }
  }

  Future<List<Submission>> getStudentSubmissions(int subjectId, int userId, String token) async {
    try {
      _isLoading = true;
      notifyListeners();

      final submissions = await _submissionService.getStudentSubmissions(userId, subjectId, token);
      
      _isLoading = false;
      notifyListeners();
      return submissions;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('Error en SubmissionProvider.getStudentSubmissions: $e');
      rethrow;
    }
  }

  Future<Submission?> getStudentSubmission2(int alumnoId, int actividadId, String token) async {
    try {
      _isLoading = true;
      notifyListeners();

      final submission = await _submissionService.getStudentSubmission2(alumnoId, actividadId, token);
      _currentSubmission = submission;
      
      _isLoading = false;
      notifyListeners();
      return submission;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('Error en SubmissionProvider.getStudentSubmission2: $e');
      rethrow;
    }
  }

  Future<String> processImageOCR(File image, String token) async {
    try {
      _isLoading = true;
      notifyListeners();

      final result = await _submissionService.processImageOCR(image, token);
      
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('Error en SubmissionProvider.processImageOCR: $e');
      rethrow;
    }
  }
} 