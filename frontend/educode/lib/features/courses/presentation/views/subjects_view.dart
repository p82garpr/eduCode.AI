import 'package:educode/features/courses/presentation/views/subject_detail_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:educode/features/courses/presentation/providers/subjects_provider.dart';
import 'package:educode/features/auth/presentation/providers/auth_provider.dart';
import 'package:educode/features/auth/presentation/pages/login_page.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'package:educode/features/courses/domain/models/subject_model.dart';

class CoursesView extends StatefulWidget {
  const CoursesView({super.key});

  @override
  State<CoursesView> createState() => _CoursesViewState();
}

class _CoursesViewState extends State<CoursesView> with SingleTickerProviderStateMixin {
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
        curve: Curves.easeInOut,
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
        final user = context.read<AuthProvider>().currentUser;

        return RefreshIndicator(
          onRefresh: () => _refreshCourses(context),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 120.0,
                floating: false,
                pinned: true,
                backgroundColor: colors.primary,
                actions: [
                  AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) => Opacity(
                      opacity: _fadeAnimation.value,
                      child: IconButton(
                        icon: Icon(
                          Icons.logout,
                          color: colors.onPrimary,
                        ),
                        onPressed: () {
                          context.read<AuthProvider>().logout();
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                              maintainState: false,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  title: AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) => Opacity(
                      opacity: _fadeAnimation.value,
                      child: Text(
                        'Mis Asignaturas',
                        style: TextStyle(
                          color: colors.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colors.primary,
                          colors.primary.withOpacity(0.8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (subjects.isEmpty)
                SliverFillRemaining(
                  child: AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) => Opacity(
                      opacity: _fadeAnimation.value,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.school_outlined,
                              size: 64,
                              color: colors.primary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              user?.tipoUsuario == 'Profesor'
                                  ? 'No tienes asignaturas creadas'
                                  : 'No estás inscrito en ninguna asignatura',
                              style: TextStyle(
                                color: colors.onSurface.withOpacity(0.7),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: AnimationLimiter(
                    child: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.85,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final course = subjects[index];
                          return AnimationConfiguration.staggeredGrid(
                            position: index,
                            duration: const Duration(milliseconds: 500),
                            columnCount: 2,
                            child: SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 1.0, end: 1.0),
                                  duration: const Duration(milliseconds: 200),
                                  builder: (context, scale, child) {
                                    return Transform.scale(
                                      scale: scale,
                                      child: Card(
                                        elevation: 4,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: InkWell(
                                          onTap: () => _navigateToCourseDetail(context, course),
                                          borderRadius: BorderRadius.circular(16),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Hero(
                                                tag: 'subject_${course.id}',
                                                child: Container(
                                                  width: 70,
                                                  height: 70,
                                                  decoration: BoxDecoration(
                                                    color: colors.primaryContainer,
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: colors.primary.withOpacity(0.2),
                                                        blurRadius: 8,
                                                        offset: const Offset(0, 4),
                                                      ),
                                                    ],
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
                                              ),
                                              const SizedBox(height: 16),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                                child: Text(
                                                  course.nombre,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: subjects.length,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
} 
