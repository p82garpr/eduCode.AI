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

  // Método para obtener un color basado en el nombre de la asignatura
  Color _getSubjectColor(String subjectName, double opacity) {
    // Genera un código de hash basado en el nombre para obtener colores consistentes
    final int hashCode = subjectName.hashCode;
    
    // Lista de colores base para las asignaturas (tonos azules/verdes)
    final List<Color> baseColors = [
      const Color(0xFF1565C0), // Azul
      const Color(0xFF0277BD), // Azul claro
      const Color(0xFF006064), // Cian oscuro
      const Color(0xFF00796B), // Verde azulado
      const Color(0xFF2E7D32), // Verde
      const Color(0xFF303F9F), // Indigo
      const Color(0xFF0097A7), // Cian
      const Color(0xFF0288D1), // Azul cielo
    ];
    
    // Selecciona un color basado en el hash del nombre
    final Color baseColor = baseColors[hashCode % baseColors.length];
    
    // Devuelve el color con la opacidad especificada
    return baseColor.withOpacity(opacity);
  }
  
  // Método para obtener un icono basado en el nombre de la asignatura
  IconData _getSubjectIcon(String subjectName) {
    final String nameLower = subjectName.toLowerCase();
    
    // Asignar iconos según palabras clave en el nombre
    if (nameLower.contains('programación') || nameLower.contains('programacion') || 
        nameLower.contains('código') || nameLower.contains('codigo') || 
        nameLower.contains('web') || nameLower.contains('app')) {
      return Icons.code;
    } else if (nameLower.contains('matemática') || nameLower.contains('matematica') ||
              nameLower.contains('cálculo') || nameLower.contains('calculo') ||
              nameLower.contains('álgebra') || nameLower.contains('algebra')) {
      return Icons.functions;
    } else if (nameLower.contains('ciencia') || nameLower.contains('física') || 
              nameLower.contains('fisica') || nameLower.contains('química') || 
              nameLower.contains('quimica') || nameLower.contains('bio')) {
      return Icons.science;
    } else if (nameLower.contains('historia') || nameLower.contains('literatura') || 
               nameLower.contains('lengua') || nameLower.contains('social')) {
      return Icons.history_edu;
    } else if (nameLower.contains('arte') || nameLower.contains('diseño') || 
               nameLower.contains('diseno') || nameLower.contains('música') || 
               nameLower.contains('musica')) {
      return Icons.palette;
    } else if (nameLower.contains('deporte') || nameLower.contains('educación física') || 
               nameLower.contains('educacion fisica')) {
      return Icons.sports_soccer;
    } else if (nameLower.contains('economía') || nameLower.contains('economia') || 
               nameLower.contains('empresa') || nameLower.contains('negocio')) {
      return Icons.business;
    } else if (nameLower.contains('ingeniería') || nameLower.contains('ingenieria') || 
               nameLower.contains('mecánica') || nameLower.contains('mecanica')) {
      return Icons.engineering;
    } else if (nameLower.contains('idioma') || nameLower.contains('lengua') || 
               nameLower.contains('inglés') || nameLower.contains('ingles') || 
               nameLower.contains('español') || nameLower.contains('espanol')) {
      return Icons.translate;
    }
    
    // Icono por defecto para otras asignaturas
    return Icons.school;
  }

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

      // Una vez tenemos los datos, navegamos con una transición personalizada
      await Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) => SubjectDetailView(
            subject: subjectDetail,
            activities: activities,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 0.05);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);
            
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: offsetAnimation,
                child: child,
              ),
            );
          },
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
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _getSubjectColor(course.nombre, 0.3),
                                              blurRadius: 12,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          borderRadius: BorderRadius.circular(16),
                                          child: Ink(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(16),
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  _getSubjectColor(course.nombre, 0.9),
                                                  _getSubjectColor(course.nombre, 0.7),
                                                ],
                                              ),
                                            ),
                                            child: InkWell(
                                              onTap: () => _navigateToCourseDetail(context, course),
                                              borderRadius: BorderRadius.circular(16),
                                              splashColor: Colors.white.withOpacity(0.1),
                                              highlightColor: Colors.transparent,
                                              child: Padding(
                                                padding: const EdgeInsets.all(16.0),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Hero(
                                                          tag: 'subject_${course.id}',
                                                          flightShuttleBuilder: (
                                                            BuildContext flightContext,
                                                            Animation<double> animation,
                                                            HeroFlightDirection flightDirection,
                                                            BuildContext fromHeroContext,
                                                            BuildContext toHeroContext,
                                                          ) {
                                                            return Material(
                                                              color: Colors.white,
                                                              borderRadius: BorderRadius.circular(12),
                                                              elevation: 4,
                                                              child: Container(
                                                                width: 50,
                                                                height: 50,
                                                                decoration: BoxDecoration(
                                                                  color: _getSubjectColor(course.nombre, 0.9),
                                                                  borderRadius: BorderRadius.circular(12),
                                                                ),
                                                                child: Center(
                                                                  child: Text(
                                                                    course.nombre.substring(0, 1).toUpperCase(),
                                                                    style: const TextStyle(
                                                                      color: Colors.white,
                                                                      fontWeight: FontWeight.bold,
                                                                      fontSize: 22,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                          child: Container(
                                                            width: 50,
                                                            height: 50,
                                                            decoration: BoxDecoration(
                                                              color: Colors.white.withOpacity(0.2),
                                                              borderRadius: BorderRadius.circular(12),
                                                            ),
                                                            child: Center(
                                                              child: Text(
                                                                course.nombre.substring(0, 1).toUpperCase(),
                                                                style: const TextStyle(
                                                                  color: Colors.white,
                                                                  fontWeight: FontWeight.bold,
                                                                  fontSize: 22,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        Icon(
                                                          _getSubjectIcon(course.nombre),
                                                          color: Colors.white.withOpacity(0.7),
                                                          size: 24,
                                                        ),
                                                      ],
                                                    ),
                                                    const Spacer(),
                                                    Text(
                                                      course.nombre,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16,
                                                        color: Colors.white,
                                                      ),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.person_outline,
                                                          color: Colors.white.withOpacity(0.7),
                                                          size: 16,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Expanded(
                                                          child: Text(
                                                            "${course.profesor.nombre} ${course.profesor.apellidos}",
                                                            style: TextStyle(
                                                              color: Colors.white.withOpacity(0.7),
                                                              fontSize: 12,
                                                            ),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
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
