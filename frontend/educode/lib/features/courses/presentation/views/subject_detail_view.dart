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
import 'package:educode/features/courses/presentation/widgets/edit_subject_dialog.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
  
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
    final user = context.read<AuthProvider>().currentUser;
    final isTeacher = user?.tipoUsuario == 'Profesor';
    final isOwner = user?.id == widget.subject.profesorId;
    final colors = Theme.of(context).colorScheme;

    // Lista de pestañas para determinar el número correcto
    final List<Widget> tabs = [
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
    ];

    // Crear las vistas correspondientes
    final List<Widget> tabViews = [
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
    ];

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
        ChangeNotifierProvider(
          create: (context) => ProfileProvider(
            profileService: ProfileService(),
          ),
        ),
      ],
      child: DefaultTabController(
        length: tabs.length, // Usar la longitud real de las pestañas
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colors.primary.withOpacity(0.05),
                colors.primary.withOpacity(0.1),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Patrón de líneas decorativas en el fondo
              Positioned.fill(
                child: CustomPaint(
                  painter: CurvesPatternPainter(
                    isDarkMode: Theme.of(context).brightness == Brightness.dark,
                  ),
                ),
              ),
              // Scaffold principal
              Scaffold(
                // Decoración con el mismo fondo estilizado de la aplicación
                backgroundColor: Colors.transparent,
                extendBodyBehindAppBar: false,
                appBar: AppBar(
                  title: Text(
                    widget.subject.nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  elevation: 0,
                  actions: [
                    if (!isTeacher)
                      IconButton(
                        icon: Icon(
                          Icons.exit_to_app,
                          color: colors.onPrimary,
                        ),
                        onPressed: _cancelEnrollment,
                        tooltip: 'Darme de baja de la asignatura',
                      ),
                  ],
                  bottom: TabBar(
                    labelColor: colors.onPrimary,
                    unselectedLabelColor: colors.onPrimary.withOpacity(0.7),
                    indicatorColor: colors.onPrimary,
                    dividerColor: Colors.transparent,
                    tabs: tabs,
                  ),
                ),
                body: TabBarView(
                  children: tabViews,
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
            ],
          ),
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

  Future<void> _editSubject(BuildContext context) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => EditSubjectDialog(
        subject: subject,
      ),
    );

    if (result != null && context.mounted) {
      try {
        final token = context.read<AuthProvider>().token;
        if (token == null) {
          throw Exception('No se encontró el token de autenticación');
        }

        // Actualizar la asignatura
        final updatedSubject = await context.read<SubjectsProvider>().updateSubject(
          subject.id,
          result,
          token,
        );
        
        if (context.mounted) {
          // Recargar la lista de asignaturas
          await context.read<SubjectsProvider>().loadSubjects(subject.profesor.id.toString(), 'Profesor', token);
          
          // Obtener las actividades actualizadas
          final updatedActivities = await context.read<SubjectsProvider>().getCourseActivities(updatedSubject.id, token);
          
          // Actualizar la vista actual con los nuevos datos
          if (context.mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => SubjectDetailView(
                  subject: updatedSubject,
                  activities: updatedActivities,
                ),
              ),
            );
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Asignatura actualizada correctamente'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al actualizar la asignatura: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
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
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        color: colors.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Descripción',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    subject.descripcion,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => _navigateToTeacherProfile(
                      context, 
                      subject.profesor.id.toString(),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Hero(
                            tag: 'subject_${subject.id}',
                            child: Material(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              color: colors.primary,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: colors.primary,
                                ),
                                child: Center(
                                  child: Text(
                                    subject.nombre.substring(0, 1).toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Profesor',
                                  style: TextStyle(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${subject.profesor.nombre} ${subject.profesor.apellidos}',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: colors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isTeacher) ...[
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.settings_outlined,
                          color: colors.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Gestión de la asignatura',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _editSubject(context),
                      icon: const Icon(Icons.edit),
                      label: const Text('Editar Asignatura'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _downloadSubjectCsv(context),
                      icon: const Icon(Icons.file_download),
                      label: const Text('Exportar Calificaciones'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _deleteSubject(context),
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Eliminar Asignatura'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.error,
                        foregroundColor: colors.onError,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
    final theme = Theme.of(context);
    final userId = context.read<AuthProvider>().currentUser?.id;
    final token = context.read<AuthProvider>().token;

    if (activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 64,
              color: colors.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No hay actividades disponibles',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colors.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: activities.length,
        itemBuilder: (context, index) {
          final activity = activities[index];
          final isOverdue = _isOverdue(activity.fechaEntrega);
          
          return FutureBuilder<bool>(
            future: !isTeacher && userId != null && token != null
              ? _checkSubmissionStatus(context, activity.id, int.parse(userId), token)
              : Future.value(false),
            builder: (context, submissionSnapshot) {
              final isSubmitted = submissionSnapshot.data ?? false;
              final showSuccess = isSubmitted;
              final showWarning = !isSubmitted && isOverdue && !isTeacher;

              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 500),
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      shadowColor: colors.shadow.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
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
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: showSuccess
                                        ? colors.primaryContainer
                                        : showWarning
                                          ? colors.errorContainer
                                          : colors.primaryContainer,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      showSuccess
                                        ? Icons.check_circle_rounded
                                        : showWarning
                                          ? Icons.warning_rounded
                                          : Icons.assignment_rounded,
                                      color: showSuccess
                                        ? colors.onPrimaryContainer
                                        : showWarning
                                          ? colors.onErrorContainer
                                          : colors.onPrimaryContainer,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          activity.titulo,
                                          style: theme.textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Fecha de entrega: ${_formatDate(activity.fechaEntrega)}',
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            color: showWarning
                                              ? colors.error
                                              : colors.onSurfaceVariant,
                                          ),
                                        ),
                                        if (showSuccess) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Entregado',
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              color: colors.primary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (isTeacher)
                                    PopupMenuButton(
                                      icon: Icon(
                                        Icons.more_vert,
                                        color: colors.onSurfaceVariant,
                                      ),
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit, 
                                                color: colors.primary,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              const Text('Editar'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete, 
                                                color: colors.error,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              const Text('Eliminar'),
                                            ],
                                          ),
                                        ),
                                      ],
                                      onSelected: (value) {
                                        if (value == 'delete') {
                                          onDeleteActivity?.call(activity.id);
                                        } else if (value == 'edit') {
                                          onEditActivity?.call(activity);
                                        }
                                      },
                                    ),
                                ],
                              ),
                              if (activity.descripcion.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceVariant.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    activity.descripcion,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                              if (activity.lenguajeProgramacion != null) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.code,
                                      size: 16,
                                      color: colors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      activity.lenguajeProgramacion!,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: colors.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<bool> _checkSubmissionStatus(BuildContext context, int activityId, int userId, String token) async {
    try {
      final submissions = await context.read<SubmissionProvider>().getActivitySubmissions(activityId, token);
      return submissions.any((submission) => submission.alumnoId == userId);
    } catch (e) {
      return false;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  bool _isOverdue(DateTime dueDate) {
    return DateTime.now().isAfter(dueDate);
  }
}

// Clase para dibujar el patrón de líneas curvas decorativas en el fondo
class CurvesPatternPainter extends CustomPainter {
  final bool isDarkMode;
  
  CurvesPatternPainter({required this.isDarkMode});
  
  @override
  void paint(Canvas canvas, Size size) {
    final wavePaint = Paint()
      ..color = isDarkMode 
          ? Colors.white.withOpacity(0.03)
          : Colors.blue.withOpacity(0.04)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    // Ondas suaves horizontales 
    final horizontalWaveSpacing = 80.0;
    final waveAmplitude = 20.0;
    final waveLength = 150.0;
    
    for (double y = horizontalWaveSpacing; y < size.height; y += horizontalWaveSpacing) {
      final path = Path();
      path.moveTo(0, y);
      
      for (double x = 0; x < size.width; x += waveLength / 2) {
        path.quadraticBezierTo(
          x + (waveLength / 4), y + waveAmplitude,
          x + (waveLength / 2), y
        );
        
        if (x + waveLength <= size.width) {
          path.quadraticBezierTo(
            x + (waveLength * 3 / 4), y - waveAmplitude,
            x + waveLength, y
          );
        }
      }
      
      canvas.drawPath(path, wavePaint);
    }
    
    // Ondas verticales en los bordes
    final verticalWavePaint = Paint()
      ..color = isDarkMode 
          ? Colors.blue.withOpacity(0.02)
          : Colors.blue.withOpacity(0.03)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    final verticalWaveSpacing = 100.0;
    final vWaveAmplitude = 15.0;
    final vWaveLength = 120.0;
    
    // Ondas en el lado derecho
    for (double x = size.width - 70; x < size.width + 10; x += 30) {
      final path = Path();
      path.moveTo(x, 0);
      
      for (double y = 0; y < size.height; y += vWaveLength / 2) {
        path.quadraticBezierTo(
          x - vWaveAmplitude, y + (vWaveLength / 4),
          x, y + (vWaveLength / 2)
        );
        
        if (y + vWaveLength <= size.height) {
          path.quadraticBezierTo(
            x + vWaveAmplitude, y + (vWaveLength * 3 / 4),
            x, y + vWaveLength
          );
        }
      }
      
      canvas.drawPath(path, verticalWavePaint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
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