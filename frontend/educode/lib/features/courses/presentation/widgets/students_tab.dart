import 'package:educode/features/courses/data/services/profile_service.dart';
import 'package:educode/features/courses/domain/models/activity_model.dart';
import 'package:educode/features/courses/presentation/providers/enrollment_provider.dart';
import 'package:educode/features/courses/presentation/views/user_profile_view.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/models/enrolled_student_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/profile_provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class StudentsTab extends StatefulWidget {
  final int subjectId;
  final List<ActivityModel> activities;
  final bool showAsStudent;

  const StudentsTab({
    super.key,
    required this.subjectId,
    required this.activities,
    required this.showAsStudent,
  });

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> with SingleTickerProviderStateMixin {
  Future<List<EnrolledStudent>>? _studentsFuture;
  bool _isLoading = false;
  late EnrollmentProvider _enrollmentProvider;
  late String? _token;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enrollmentProvider = context.read<EnrollmentProvider>();
    _token = context.read<AuthProvider>().token;
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    if (_isLoading || _token == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final students = await _enrollmentProvider.getEnrolledStudents(
        widget.subjectId, 
        _token!
      );
            
      if (mounted) {
        setState(() {
          _studentsFuture = Future.value(students);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _studentsFuture = Future.error(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleRemoveStudent(EnrolledStudent student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar expulsión'),
        content: Text(
          '¿Estás seguro de que quieres expulsar a ${student.nombre} de la asignatura?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Expulsar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _enrollmentProvider.removeStudentFromSubject(
          widget.subjectId,
          student.id,
          _token!,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Estudiante expulsado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
          _loadStudents(); // Recargar la lista después de expulsar
        }
      } catch (e) {
        if (mounted) {
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

  void _sendEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
    );
    
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return RefreshIndicator(
      onRefresh: _loadStudents,
      child: FutureBuilder<List<EnrolledStudent>>(
        future: _studentsFuture,
        builder: (context, snapshot) {
          if (_isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
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
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: colors.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error al cargar los estudiantes: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.error),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadStudents,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: colors.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final students = snapshot.data ?? [];

          if (students.isEmpty) {
            return Center(
              child: AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) => Opacity(
                  opacity: _fadeAnimation.value,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: colors.primary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay estudiantes matriculados',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: colors.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          _controller.forward();

          return AnimationLimiter(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];
                return AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(milliseconds: 500),
                  child: SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shadowColor: colors.shadow.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChangeNotifierProvider(
                                  create: (_) => ProfileProvider(
                                    profileService: ProfileService(),
                                  ),
                                  child: UserProfileView(
                                    userId: student.id.toString(),
                                    userType: 'alumno',
                                  ),
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: colors.primaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      student.nombre[0].toUpperCase(),
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        color: colors.onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
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
                                        '${student.nombre} ${student.apellidos}',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        student.email,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!widget.showAsStudent) ...[
                                  IconButton(
                                    icon: const Icon(Icons.email_outlined),
                                    color: colors.primary,
                                    onPressed: () => _sendEmail(student.email),
                                    tooltip: 'Enviar correo',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    color: colors.error,
                                    onPressed: () => _handleRemoveStudent(student),
                                    tooltip: 'Expulsar alumno',
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
            ),
          );
        },
      ),
    );
  }
} 