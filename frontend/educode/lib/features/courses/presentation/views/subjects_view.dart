import 'package:educode/features/courses/presentation/views/subject_detail_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:educode/features/courses/presentation/providers/subjects_provider.dart';
import 'package:educode/features/auth/presentation/providers/auth_provider.dart';

import 'package:educode/features/courses/domain/models/subject_model.dart';

class CoursesView extends StatelessWidget {
  const CoursesView({super.key});

  Future<void> _navigateToCourseDetail(BuildContext context, Subject course) async {
    final subjectsProvider = context.read<SubjectsProvider>();
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    

    if (token == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay sesión activa')),
      );
      return;
    }
    
    try {
      // Obtener los datos primero
      final subjectDetail = await subjectsProvider.getSubjectDetail(course.id, token);
      final activities = await subjectsProvider.getCourseActivities(course.id, token);


      if (!context.mounted) return;

      // Una vez tenemos los datos, navegamos
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SubjectDetailView(
            subject: subjectDetail,
            activities: activities,
          ),
        ),

      );
    } catch (e) {
      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _refreshCourses(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    final token = authProvider.token;
    
    if (user != null && token != null) {
      await context.read<SubjectsProvider>().loadSubjects(
        user.id.toString(),
        user.tipoUsuario,
        token,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SubjectsProvider>(
      builder: (context, subjectsProvider, _) {
        if (subjectsProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (subjectsProvider.error != null) {
          return Center(child: Text(subjectsProvider.error!));
        }

        final subjects = subjectsProvider.subjects;
        final colors = Theme.of(context).colorScheme;

        if (subjects.isEmpty) {
          return Center(
            child: Text(
              'No hay cursos disponibles',
              style: TextStyle(color: colors.onSurface.withOpacity(0.7)),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => _refreshCourses(context),
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              final course = subjects[index];
              return Card(
                elevation: 2,
                child: InkWell(
                  onTap: () => _navigateToCourseDetail(context, course),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            course.nombre.substring(0, 2).toUpperCase(),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: colors.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          course.nombre,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
} 
