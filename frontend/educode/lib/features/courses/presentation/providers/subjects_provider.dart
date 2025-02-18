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
  
  SubjectsProvider(this._subjectsService);

  // Getters
  List<Subject> get subjects => _subjects;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Subject? get currentSubject => _currentSubject;

  // Setter para subjects
  set subjects(List<Subject> value) {
    _subjects = value;
    notifyListeners();
  }

  Future<void> loadSubjects(String userId, String userType, String token) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _subjects = await _subjectsService.getCoursesByUser(userId, userType, token);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      throw Exception('Error al cargar las asignaturas: ${e.toString()}');
    }
  }

  Future<void> createSubject(Map<String, String> data, String token) async {
    try {
      final newSubject = await _subjectsService.createSubject(data, token);
      _subjects = [..._subjects, newSubject];
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error en provider: $e');
      }
    }
  }

  void setCurrentSubject(Subject subject) {
    _currentSubject = subject;
    notifyListeners();
  }

  Future<Subject> updateSubject(int subjectId, Map<String, String> data, String token) async {
    try {
      final updatedSubject = await _subjectsService.updateSubject(subjectId, data, token);
      _subjects = _subjects.map((subject) => 
        subject.id == subjectId ? updatedSubject : subject
      ).toList();
      notifyListeners();
      return updatedSubject;
    } catch (e) {
      throw Exception('Error al actualizar la asignatura: ${e.toString()}');
    }
  }

  Future<Subject> getCourseDetail(int courseId, String token) async {
    try {
      return await _subjectsService.getCourseDetail(courseId, token);
    } catch (e) {
      throw Exception('Error al cargar los detalles del curso: ${e.toString()}');
    }
  }

  Future<List<dynamic>> getAvailableSubjects(String token) async {
    debugPrint('SubjectsProvider: getAvailableSubjects called');
    try {
      final subjects = await _subjectsService.getAvailableSubjects(token);
      _availableSubjects = subjects;
      return subjects;
    } catch (e) {
      debugPrint('SubjectsProvider: Error: $e');
      rethrow;
    }
  }

  Future<List<ActivityModel>> getCourseActivities(int courseId, String token) async {
    try {
      return await _subjectsService.getCourseActivities(courseId, token);
    } catch (e) {
      throw Exception('Error al cargar las actividades del curso: ${e.toString()}');
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
}