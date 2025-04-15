import 'package:educode/features/courses/domain/models/activity_model.dart';
import 'package:flutter/foundation.dart';
import '../../data/services/subjects_service.dart';
import '../../domain/models/subject_model.dart';

class SubjectsProvider extends ChangeNotifier {
  final SubjectsService _subjectsService;
  List<Subject> _subjects = [];
  bool _isLoading = false;
  String? _error;
  Subject? _currentSubject;
  List<Subject> _availableSubjects = [];
  int _retryAttempts = 0;
  static const int maxRetries = 3;
  
  SubjectsProvider(this._subjectsService);

  // Getters
  List<Subject> get subjects => _subjects;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Subject? get currentSubject => _currentSubject;

  // Limpiar estado
  void clearState() {
    _subjects = [];
    _error = null;
    _currentSubject = null;
    _availableSubjects = [];
    _retryAttempts = 0;
    notifyListeners();
  }

  Future<void> loadSubjects(String userId, String userType, String token) async {
    if (_isLoading) return; // Evitar múltiples cargas simultáneas
    
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      while (_retryAttempts < maxRetries) {
        try {
          _subjects = await _subjectsService.getCoursesByUser(userId, userType, token);
          _retryAttempts = 0; // Resetear intentos si es exitoso
          break;
        } catch (e) {
          _retryAttempts++;
          if (_retryAttempts >= maxRetries) {
            throw e;
          }
          await Future.delayed(Duration(seconds: _retryAttempts));
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Error al cargar las asignaturas. Por favor, inténtalo de nuevo';
      _isLoading = false;
      notifyListeners();
      throw Exception(_error);
    }
  }

  Future<void> createSubject(Map<String, String> data, String token) async {
    try {
      _error = null;
      final newSubject = await _subjectsService.createSubject(data, token);
      _subjects = [..._subjects, newSubject];
      notifyListeners();
    } catch (e) {
      _error = 'Error al crear la asignatura';
      notifyListeners();
      throw Exception(_error);
    }
  }

  void setCurrentSubject(Subject subject) {
    _currentSubject = subject;
    notifyListeners();
  }

  Future<Subject> updateSubject(int subjectId, Map<String, String> data, String token) async {
    try {
      _error = null;
      final updatedSubject = await _subjectsService.updateSubject(subjectId, data, token);
      _subjects = _subjects.map((subject) => 
        subject.id == subjectId ? updatedSubject : subject
      ).toList();
      notifyListeners();
      return updatedSubject;
    } catch (e) {
      _error = 'Error al actualizar la asignatura';
      notifyListeners();
      throw Exception(_error);
    }
  }

  Future<Subject> getSubjectDetail(int subjectId, String token) async {
    try {
      _error = null;
      return await _subjectsService.getSubjectDetail(subjectId, token);
    } catch (e) {
      _error = 'Error al cargar los detalles de la asignatura';
      notifyListeners();
      throw Exception(_error);
    }
  }

  Future<List<dynamic>> getAvailableSubjects(String token) async {
    try {
      _error = null;
      final subjects = await _subjectsService.getAvailableSubjects(token);
      _availableSubjects = subjects;
      return subjects;
    } catch (e) {
      _error = 'Error al cargar las asignaturas disponibles';
      notifyListeners();
      throw Exception(_error);
    }
  }

  Future<List<ActivityModel>> getCourseActivities(int courseId, String token) async {
    try {
      _error = null;
      return await _subjectsService.getCourseActivities(courseId, token);
    } catch (e) {
      _error = 'Error al cargar las actividades del curso';
      notifyListeners();
      throw Exception(_error);
    }
  }

  Future<String> downloadSubjectCsv(int subjectId, String token) async {
    try {
      return await _subjectsService.downloadSubjectCsv(subjectId, token);
    } catch (e) {
      debugPrint('Error en SubjectsProvider.downloadSubjectCsv: $e');
      rethrow;
    }
  }

  Future<void> deleteSubject(int subjectId, String token) async {
    try {
      await _subjectsService.deleteSubject(subjectId, token);
    } catch (e) {
      throw Exception('Error al eliminar la asignatura: $e');
    }
  }

  @override
  void dispose() {
    clearState();
    super.dispose();
  }
}