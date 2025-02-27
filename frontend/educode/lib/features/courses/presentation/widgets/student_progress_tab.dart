import 'package:educode/features/courses/presentation/providers/submission_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:educode/features/auth/presentation/providers/auth_provider.dart';
import 'package:educode/features/courses/domain/models/activity_model.dart';
import 'package:educode/features/courses/domain/models/submission_model.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

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

class _StudentProgressTabState extends State<StudentProgressTab> with SingleTickerProviderStateMixin {
  Future<List<Submission>>? _submissionsFuture;
  SubmissionProvider? _submissionProvider;
  String? _token;
  bool _isLoading = false;
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeInOut),
      ),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
    final colors = theme.colorScheme;

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
              child: AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) => Opacity(
                  opacity: _fadeAnimation.value,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, 
                        size: 64, 
                        color: colors.error
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error al cargar las entregas: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.error),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadSubmissions,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final submissions = snapshot.data ?? [];
          final completedActivities = submissions.where((s) => s.id != 0).length;
          final completionRate = widget.activities.isEmpty 
              ? 0.0 
              : completedActivities / widget.activities.length;
          
          final totalActivities = widget.activities.length;
          final sumOfGrades = submissions
              .where((s) => s.calificacion != null)
              .map((s) => s.calificacion!)
              .fold(0.0, (a, b) => a + b);
          final averageGrade = totalActivities > 0 
              ? sumOfGrades / totalActivities 
              : 0.0;
          
          final gradeRate = averageGrade / 10;

          _controller.forward();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: AnimationLimiter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: AnimationConfiguration.toStaggeredList(
                  duration: const Duration(milliseconds: 600),
                  childAnimationBuilder: (widget) => SlideAnimation(
                    horizontalOffset: 50.0,
                    child: FadeInAnimation(child: widget),
                  ),
                  children: [
                    Text(
                      'Resumen de Progreso',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      elevation: 4,
                      shadowColor: colors.shadow.withOpacity(0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Actividades Completadas',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        color: colors.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '$completedActivities de ${widget.activities.length}',
                                      style: theme.textTheme.headlineMedium?.copyWith(
                                        color: colors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: colors.primaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.assignment_turned_in_rounded,
                                    color: colors.onPrimaryContainer,
                                    size: 32,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            AnimatedBuilder(
                              animation: _progressAnimation,
                              builder: (context, child) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value: completionRate * _progressAnimation.value,
                                        backgroundColor: colors.primaryContainer.withOpacity(0.3),
                                        valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                                        minHeight: 8,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Nota Media',
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                color: colors.primary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '${averageGrade.toStringAsFixed(2)}/10',
                                              style: theme.textTheme.headlineMedium?.copyWith(
                                                color: colors.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: colors.primaryContainer,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.grade_rounded,
                                            color: colors.onPrimaryContainer,
                                            size: 32,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value: gradeRate * _progressAnimation.value,
                                        backgroundColor: colors.primaryContainer.withOpacity(0.3),
                                        valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                                        minHeight: 8,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Historial de Entregas',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
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
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shadowColor: colors.shadow.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: submission.id != 0 
                                ? colors.primaryContainer 
                                : colors.errorContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              submission.id != 0 
                                ? Icons.check_circle_rounded 
                                : Icons.pending_rounded,
                              color: submission.id != 0 
                                ? colors.onPrimaryContainer 
                                : colors.onErrorContainer,
                              size: 24,
                            ),
                          ),
                          title: Text(
                            activity.titulo,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              if (submission.id != 0) ...[
                                Text(
                                  'Calificación: ${submission.calificacion?.toStringAsFixed(2) ?? 'Pendiente'}/10',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  'No entregado',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colors.error,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
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