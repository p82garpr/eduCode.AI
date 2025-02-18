import 'package:educode/features/courses/presentation/providers/submission_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:educode/features/auth/presentation/providers/auth_provider.dart';
import 'package:educode/features/courses/domain/models/activity_model.dart';
import 'package:educode/features/courses/domain/models/submission_model.dart';

class StudentProgressTab extends StatefulWidget {
  final int subjectId;
  final List<ActivityModel> activities;

  const StudentProgressTab({
    super.key,
    required this.subjectId,
    required this.activities,
  });

  @override
  State<StudentProgressTab> createState() => _StudentProgressTabState();
}

class _StudentProgressTabState extends State<StudentProgressTab> {
  Future<List<Submission>>? _submissionsFuture;
  SubmissionProvider? _submissionProvider;
  String? _token;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Programar la inicialización para después del build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  void _initializeData() {
    if (!mounted) return;
    _submissionProvider = context.read<SubmissionProvider>();
    _token = context.read<AuthProvider>().token;
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    if (_isLoading || _token == null || _submissionProvider == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = context.read<AuthProvider>().currentUser?.id;
      if (userId == null) throw Exception('Usuario no encontrado');

      final submissions = await _submissionProvider!.getStudentSubmissions(
        widget.subjectId,
        int.parse(userId),
        _token!,
      );

      if (mounted) {
        setState(() {
          _submissionsFuture = Future.value(submissions);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submissionsFuture = Future.error(e);
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final secondaryColor = theme.colorScheme.secondary;

    return RefreshIndicator(
      onRefresh: _loadSubmissions,
      child: FutureBuilder<List<Submission>>(
        future: _submissionsFuture,
        builder: (context, snapshot) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error al cargar las entregas: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadSubmissions,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          final submissions = snapshot.data ?? [];
          final completedActivities = submissions.where((s) => s.id != 0).length;
          final completionRate = widget.activities.isEmpty 
              ? 0.0 
              : completedActivities / widget.activities.length;
          final averageGrade = submissions.isEmpty 
              ? 0.0 
              : submissions
                  .where((s) => s.calificacion != null)
                  .map((s) => s.calificacion!)
                  .fold(0.0, (a, b) => a + b) / 
                  submissions.where((s) => s.calificacion != null).length;
          final gradeRate = averageGrade / 10;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resumen de Progreso',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Card del Resumen de Progreso
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Actividades Completadas',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '$completedActivities de ${widget.activities.length}',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: completionRate,
                              backgroundColor: secondaryColor,
                              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Nota Media',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${averageGrade.toStringAsFixed(2)}/10',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: gradeRate,
                              backgroundColor: secondaryColor,
                              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Título de Historial de Entregas
                  Text(
                    'Historial de Entregas',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Lista de entregas
                  ...widget.activities.map((activity) {
                    final submission = submissions.firstWhere(
                      (s) => s.actividadId == activity.id,
                      orElse: () => Submission(
                        id: 0,
                        actividadId: activity.id,
                        alumnoId: int.parse(context.read<AuthProvider>().currentUser!.id),
                        fechaEntrega: DateTime.now(),
                        calificacion: null,
                        textoOcr: '',
                        nombreArchivo: '',
                        tipoImagen: '',
                      ),
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: Text(
                          activity.titulo,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: submission.id != 0
                            ? Text(
                                'Calificación: ${submission.calificacion?.toStringAsFixed(2) ?? 'Pendiente'}/10',
                                style: TextStyle(color: primaryColor),
                              )
                            : null,
                        trailing: submission.id != 0
                            ? Icon(Icons.check_circle, color: primaryColor)
                            : Icon(Icons.pending, color: Colors.orange.shade700),
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ignore: unused_element
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}