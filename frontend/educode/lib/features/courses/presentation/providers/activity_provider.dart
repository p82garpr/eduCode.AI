import 'package:flutter/foundation.dart';
import '../../data/services/activity_service.dart';
import '../../domain/models/activity_model.dart';

class ActivityProvider extends ChangeNotifier {
  final ActivityService _activityService;
  List<ActivityModel> _activities = [];
  bool _isLoading = false;
  String? _error;
  ActivityModel? _currentActivity;

  ActivityProvider(this._activityService);

  // Getters
  List<ActivityModel> get activities => _activities;
  bool get isLoading => _isLoading;
  String? get error => _error;
  ActivityModel? get currentActivity => _currentActivity;

  Future<void> loadActivities(int subjectId, String token) async {
    try {
      _isLoading = true;
      notifyListeners();

      _activities = await _activityService.getActivities(subjectId, token);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('Error en ActivityProvider.loadActivities: $e');
      rethrow;
    }
  }

  Future<ActivityModel> createActivity(int subjectId, Map<String, dynamic> activityData, String token) async {
    try {
      _isLoading = true;
      notifyListeners();

      final newActivity = await _activityService.createActivity(subjectId, activityData, token);
      _activities = [..._activities, newActivity];
      
      _isLoading = false;
      notifyListeners();
      return newActivity;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('Error en ActivityProvider.createActivity: $e');
      rethrow;
    }
  }

  Future<ActivityModel> updateActivity(int activityId, Map<String, dynamic> activityData, String token) async {
    try {
      _isLoading = true;
      notifyListeners();

      final updatedActivity = await _activityService.updateActivity(activityId, activityData, token);
      _activities = _activities.map((activity) => 
        activity.id == activityId ? updatedActivity : activity
      ).toList();
      
      _isLoading = false;
      notifyListeners();
      return updatedActivity;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('Error en ActivityProvider.updateActivity: $e');
      rethrow;
    }
  }

  Future<void> deleteActivity(int activityId, String token) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _activityService.deleteActivity(activityId, token);
      _activities = _activities.where((activity) => activity.id != activityId).toList();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('Error en ActivityProvider.deleteActivity: $e');
      rethrow;
    }
  }

  Future<ActivityModel> getActivity(int activityId, String token) async {
    try {
      return await _activityService.getActivity(activityId, token);
    } catch (e) {
      throw Exception('Error al obtener la actividad: ${e.toString()}');
    }
  }

  Future<String> downloadActivityCsv(int activityId, String token) async {
    try {
      return await _activityService.downloadActivityCsv(activityId, token);
    } catch (e) {
      debugPrint('Error en ActivityProvider.downloadActivityCsv: $e');
      rethrow;
    }
  }

  void setCurrentActivity(ActivityModel activity) {
    _currentActivity = activity;
    notifyListeners();
  }
} 