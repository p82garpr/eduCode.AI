import 'package:educode/features/courses/data/services/activity_service.dart';
import 'package:educode/features/courses/data/services/enrollment_service.dart';
import 'package:educode/features/courses/data/services/profile_service.dart';
import 'package:educode/features/courses/data/services/submission_service.dart';
import 'package:educode/features/courses/domain/models/activity_model.dart';
import 'package:educode/features/courses/domain/models/enrolled_student_model.dart';
import 'package:educode/features/courses/domain/models/subject_model.dart';
import 'package:educode/features/courses/domain/models/submission_model.dart';
import 'package:educode/features/courses/presentation/providers/activity_provider.dart';
import 'package:educode/features/courses/presentation/providers/enrollment_provider.dart';
import 'package:educode/features/courses/presentation/providers/submission_provider.dart';
import 'package:educode/features/courses/presentation/widgets/create_activity_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:educode/features/auth/presentation/providers/auth_provider.dart';

import 'package:educode/features/courses/presentation/providers/subjects_provider.dart';

import 'package:educode/features/courses/presentation/widgets/students_tab.dart';
import 'package:educode/features/courses/presentation/views/activity_submissions_view.dart';
import 'statistics_view.dart';
import 'package:educode/features/courses/presentation/widgets/edit_activity_dialog.dart';
import 'package:educode/features/courses/presentation/widgets/student_progress_tab.dart';
import 'package:educode/features/courses/presentation/views/user_profile_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../providers/profile_provider.dart';
  
class SubjectDetailView extends StatefulWidget {
  final Subject subject;
  final List<ActivityModel> activities;

  const SubjectDetailView({
    super.key,
    required this.subject,
    required this.activities,
  });

  @override
  State<SubjectDetailView> createState() => _SubjectDetailViewState();
}

class _SubjectDetailViewState extends State<SubjectDetailView> {
  late List<ActivityModel> _activities;
  // ignore: unused_field
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _activities = widget.activities;
  }

  Future<void> _refreshActivities() async {
    if (!mounted) return;
    
    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) return;

      final newActivities = await context
          .read<SubjectsProvider>()
          .getCourseActivities(widget.subject.id, token);
          
      setState(() {
        _activities = newActivities;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar las actividades: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteActivity(int activityId) async {
    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) return;

      // Mostrar diálogo de confirmación
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Eliminar actividad'),
          content: const Text('¿Estás seguro de que quieres eliminar esta actividad?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );

      if (confirm != true || !mounted) return;

      // Eliminar la actividad
      await context
          .read<ActivityProvider>()
          .deleteActivity(activityId, token);

      // Actualizar la lista local
      setState(() {
        _activities.removeWhere((activity) => activity.id == activityId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Actividad eliminada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar la actividad: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editActivity(ActivityModel activity) async {
    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) return;

      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => EditActivityDialog(activity: activity),
      );

      if (result != null && mounted) {
        // Mostrar indicador de carga
        setState(() => _isLoading = true);

        // Actualizar la actividad
        // ignore: unused_local_variable
        final updatedActivity = await context
            .read<ActivityProvider>()
            .updateActivity(activity.id, result, token);

        // Recargar todas las actividades para asegurar la sincronización
        final newActivities = await context
            .read<SubjectsProvider>()
            .getCourseActivities(widget.subject.id, token);

        if (!mounted) return;

        // Actualizar el estado
        setState(() {
          _activities = newActivities;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Actividad actualizada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar la actividad: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelEnrollment() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar inscripción'),
        content: const Text('¿Estás seguro de que quieres darte de baja de esta asignatura?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Darme de baja'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // ignore: use_build_context_synchronously
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.token;
      final userId = authProvider.currentUser?.id;
      
      if (token == null || userId == null) return;

      // ignore: use_build_context_synchronously
      await context.read<EnrollmentProvider>().cancelEnrollment(
        widget.subject.id,
        int.parse(userId),
        token,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Te has dado de baja correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        // Volver a la página anterior
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al darte de baja: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteSubject() async {
    // Mostrar diálogo de confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar asignatura'),
        content: const Text('¿Estás seguro de que quieres eliminar esta asignatura? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) return;

      // Eliminar la asignatura
      await context.read<SubjectsProvider>().deleteSubject(
        widget.subject.id,
        token,
      );

      if (!mounted) return;

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Asignatura eliminada correctamente'),
          backgroundColor: Colors.green,
        ),
      );

      // Volver a la página anterior
      Navigator.of(context).pop();

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar la asignatura: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTeacher = context.read<AuthProvider>().currentUser?.tipoUsuario == 'Profesor';
    final colors = Theme.of(context).colorScheme;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => EnrollmentProvider(
            EnrollmentService(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => ActivityProvider(
            ActivityService(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => SubmissionProvider(
            SubmissionService(),
          ),
        ),
      ],
      child: DefaultTabController(
        length: isTeacher ? 4 : 4,
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.subject.nombre),
            actions: [
              if (isTeacher)
                IconButton(
                  icon: Icon(
                    Icons.delete_forever,
                    color: colors.error,
                  ),
                  onPressed: _deleteSubject,
                  tooltip: 'Eliminar asignatura',
                ),
              if (!isTeacher)
                IconButton(
                  icon: Icon(
                    Icons.exit_to_app,
                    color: colors.error,
                  ),
                  onPressed: _cancelEnrollment,
                  tooltip: 'Darme de baja de la asignatura',
                ),
            ],
            bottom: TabBar(
              isScrollable: false,
              tabs: [
                const Tab(
                  icon: Icon(Icons.info_outline),
                  text: 'Info',
                ),
                const Tab(
                  icon: Icon(Icons.assignment_outlined),
                  text: 'Tareas',
                ),
                const Tab(
                  icon: Icon(Icons.people_outline),
                  text: 'Alumnos',
                ),
                if (isTeacher)
                  const Tab(
                    icon: Icon(Icons.analytics_outlined),
                    text: 'Estadísticas',
                  )
                else
                  const Tab(
                    icon: Icon(Icons.analytics_outlined),
                    text: 'Mi Progreso',
                  ),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _SubjectInfoTab(subject: widget.subject),
              _ActivitiesTab(
                activities: _activities,
                isTeacher: isTeacher,
                subjectId: widget.subject.id,
                onDeleteActivity: _deleteActivity,
                onEditActivity: _editActivity,
              ),
              StudentsTab(
                subjectId: widget.subject.id, 
                activities: _activities,
                showAsStudent: !isTeacher,
              ),
              if (isTeacher)
                _StatisticsTab(
                  subject: widget.subject,
                  activities: _activities,
                )
              else
                StudentProgressTab(
                  subjectId: widget.subject.id,
                  activities: _activities,
                ),
            ],
          ),
          floatingActionButton: isTeacher
              ? Builder(
                  builder: (context) {
                    final tabController = DefaultTabController.of(context);
                    return StreamBuilder<int>(
                      stream: Stream.periodic(
                        const Duration(milliseconds: 100),
                        (_) => tabController.index,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.data == 1) {
                          return FloatingActionButton(
                            onPressed: () async {
                              final result = await showDialog(
                                context: context,
                                builder: (context) => const CreateActivityDialog(),
                              );

                              if (result != null && mounted) {
                                try {
                                  final token = context.read<AuthProvider>().token;
                                  if (token == null) return;

                                  final activityProvider = context.read<ActivityProvider>();
                                  final newActivity = await activityProvider.createActivity(
                                    widget.subject.id,
                                    result,
                                    token,
                                  );

                                  setState(() {
                                    _activities = [..._activities, newActivity];
                                  });

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Actividad creada correctamente'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (kDebugMode) {
                                    print('Error al crear actividad: $e');
                                  }
                                  if (mounted) {
                                    await _refreshActivities();
                                    
                                    if (!e.toString().contains('Error de conexión')) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: ${e.toString()}'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                }
                              }
                            },
                            child: const Icon(Icons.add),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    );
                  },
                )
              : null,
        ),
      ),
    );
  }

  Future<void> _downloadSubjectCsv(BuildContext context) async {
    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) return;

      // Obtener el CSV usando el provider
      final csvString = await context.read<SubjectsProvider>()
          .downloadSubjectCsv(widget.subject.id, token);

      // Crear archivo temporal
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/calificaciones_${widget.subject.nombre}.csv');
      await file.writeAsString(csvString);

      // Compartir el archivo
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Calificaciones de ${widget.subject.nombre}',
      );

    } catch (e) {
      if (mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar las calificaciones: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Tab de Información
class _SubjectInfoTab extends StatelessWidget {
  final Subject subject;

  const _SubjectInfoTab({required this.subject});

  void _navigateToTeacherProfile(BuildContext context, String teacherId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider(
          create: (_) => ProfileProvider(
            profileService: ProfileService(),
          ),
          child: UserProfileView(
            userId: teacherId,
            userType: 'Profesor',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isTeacher = context.read<AuthProvider>().currentUser?.tipoUsuario == 'Profesor';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isTeacher) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ElevatedButton.icon(
                onPressed: () => _downloadSubjectCsv(context),
                icon: const Icon(Icons.file_download),
                label: const Text('Exportar Calificaciones'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ElevatedButton.icon(
                onPressed: () => _deleteSubject(context),
                icon: const Icon(Icons.delete_forever),
                label: const Text('Eliminar Asignatura'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Descripción',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(subject.descripcion),
                  const SizedBox(height: 16),
                  const Divider(),
                  InkWell(
                    onTap: () => _navigateToTeacherProfile(
                      context, 
                      subject.profesor.id.toString(),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colors.primary,
                        child: Text(
                          subject.profesor.nombre.substring(0, 1).toUpperCase(),
                        ),
                      ),
                      title: const Text('Profesor'),
                      subtitle: Text(
                        '${subject.profesor.nombre} ${subject.profesor.apellidos}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSubject(BuildContext context) async {
    // Mostrar diálogo de confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar asignatura'),
        content: const Text('¿Estás seguro de que quieres eliminar esta asignatura? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) return;

      // Eliminar la asignatura
      await context.read<SubjectsProvider>().deleteSubject(
        subject.id,
        token,
      );

      if (!context.mounted) return;

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Asignatura eliminada correctamente'),
          backgroundColor: Colors.green,
        ),
      );

      // Volver a la página anterior
      Navigator.of(context).pop();

    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar la asignatura: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _downloadSubjectCsv(BuildContext context) async {
    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) return;

      // Obtener el CSV usando el provider
      final csvString = await context.read<SubjectsProvider>()
          .downloadSubjectCsv(subject.id, token);

      // Crear archivo temporal
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/calificaciones_${subject.nombre}.csv');
      await file.writeAsString(csvString);

      // Compartir el archivo
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Calificaciones de ${subject.nombre}',
      );

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar las calificaciones: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Tab de Actividades
class _ActivitiesTab extends StatelessWidget {
  final List<ActivityModel> activities;
  final bool isTeacher;
  final int subjectId;
  final Function(int)? onDeleteActivity;
  final Function(ActivityModel)? onEditActivity;

  const _ActivitiesTab({
    required this.activities,
    required this.isTeacher,
    required this.subjectId,
    this.onDeleteActivity,
    this.onEditActivity,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return activities.isEmpty
        ? const Center(child: Text('No hay actividades disponibles'))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final activity = activities[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    activity.titulo,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(activity.descripcion),
                      const SizedBox(height: 4),
                      Text(
                        'Fecha de entrega: ${_formatDate(activity.fechaEntrega)}',
                        style: TextStyle(
                          color: _isOverdue(activity.fechaEntrega)
                              ? colors.error
                              : colors.primary,
                        ),
                      ),
                    ],
                  ),
                  trailing: isTeacher
                      ? PopupMenuButton(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Editar'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Eliminar'),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'delete') {
                              onDeleteActivity?.call(activity.id);
                            } else if (value == 'edit') {
                              onEditActivity?.call(activity);
                            }
                          },
                        )
                      : null,
                  onTap: () {
                    if (isTeacher) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ActivitySubmissionsView(
                            activity: activity,
                            subjectId: subjectId,
                          ),
                        ),
                      );
                    } else {
                      Navigator.pushNamed(
                        context,
                        '/student-activity-submission',
                        arguments: {
                          'activityId': activity.id,
                          'activityTitle': activity.titulo,
                        },
                      );
                    }
                  },
                ),
              );
            },
          );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  bool _isOverdue(DateTime dueDate) {
    return DateTime.now().isAfter(dueDate);
  }
}

// Nuevo widget para manejar la carga de datos de estadísticas
class _StatisticsTab extends StatelessWidget {
  final Subject subject;
  final List<ActivityModel> activities;

  const _StatisticsTab({
    required this.subject,
    required this.activities,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EnrolledStudent>>(
      future: context.read<EnrollmentProvider>().getEnrolledStudents(
        subject.id,
        context.read<AuthProvider>().token ?? '',
      ),
      builder: (context, studentsSnapshot) {
        if (studentsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (studentsSnapshot.hasError) {
          return Center(child: Text('Error: ${studentsSnapshot.error}'));
        }

        final students = studentsSnapshot.data ?? [];

        return FutureBuilder<List<Submission>>(
          future: _loadAllSubmissions(context),
          builder: (context, submissionsSnapshot) {
            if (submissionsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (submissionsSnapshot.hasError) {
              return Center(child: Text('Error: ${submissionsSnapshot.error}'));
            }

            final submissions = submissionsSnapshot.data ?? [];

            return StatisticsView(
              activities: activities,
              students: students,
              submissions: submissions,
            );
          },
        );
      },
    );
  }

  Future<List<Submission>> _loadAllSubmissions(BuildContext context) async {
    final token = context.read<AuthProvider>().token ?? '';
    
    final submissionLists = await Future.wait(
      activities.map((activity) => 
        context.read<SubmissionProvider>().getActivitySubmissions(activity.id, token)
      ),
    );
    
    return submissionLists.expand((list) => list).toList();
  }
} 