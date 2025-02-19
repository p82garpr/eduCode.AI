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

class _StudentsTabState extends State<StudentsTab> {
  Future<List<EnrolledStudent>>? _studentsFuture;
  bool _isLoading = false;
  late EnrollmentProvider _enrollmentProvider;
  late String? _token;

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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar los estudiantes: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadStudents,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          final students = snapshot.data ?? [];

          if (students.isEmpty) {
            return const Center(
              child: Text('No hay estudiantes matriculados en esta asignatura'),
            );
          }

          return ListView.builder(
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(student.nombre[0]),
                ),
                title: Text(student.nombre),
                subtitle: Text(student.email),
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
                trailing: widget.showAsStudent
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.email),
                            color: Theme.of(context).colorScheme.primary,
                            onPressed: () => _sendEmail(student.email),
                            tooltip: 'Enviar correo',
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            color: Colors.red,
                            onPressed: () => _handleRemoveStudent(student),
                            tooltip: 'Expulsar alumno',
                          ),
                        ],
                      ),
              );
            },
          );
        },
      ),
    );
  }
} 