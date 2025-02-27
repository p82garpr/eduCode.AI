import 'package:educode/features/courses/presentation/pages/home_page.dart';
import 'package:educode/features/courses/presentation/providers/enrollment_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../courses/presentation/providers/subjects_provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../widgets/enrollment_dialog.dart';

class SearchCoursesView extends StatefulWidget {
  const SearchCoursesView({super.key});

  @override
  _SearchCoursesViewState createState() => _SearchCoursesViewState();
}

class _SearchCoursesViewState extends State<SearchCoursesView> with SingleTickerProviderStateMixin {
  Future<List<dynamic>>? _subjectsFuture;
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey = GlobalKey<ScaffoldMessengerState>();
  AuthProvider? _authProvider;
  SubjectsProvider? _subjectsProvider;
  EnrollmentProvider? _enrollmentProvider;
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _subjectsProvider = Provider.of<SubjectsProvider>(context, listen: false);
    _enrollmentProvider = Provider.of<EnrollmentProvider>(context, listen: false);
    _loadSubjects();
  }

  void _loadSubjects() {
    final token = _authProvider?.token;
    if (token != null && _subjectsProvider != null) {
      setState(() {
        _subjectsFuture = _subjectsProvider!.getAvailableSubjects(token);
      });
    }
  }

  Widget _buildEnrollButton(dynamic subject) {
    final subjectsProvider = context.watch<SubjectsProvider>();
    final isEnrolled = subjectsProvider.subjects.any((s) => s.id == subject.id);
    final colors = Theme.of(context).colorScheme;

    if (isEnrolled) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.green.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: 20,
              color: Colors.green.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              'Inscrito',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showSubjectDetails(context, subject),
        icon: const Icon(Icons.add, size: 20),
        label: const Text(
          'Inscribirse',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    
    return Scaffold(
      key: _scaffoldKey,
      body: FutureBuilder<List<dynamic>>(
        future: _subjectsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadSubjects,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          final subjects = snapshot.data ?? [];

          if (subjects.isEmpty) {
            return Center(
              child: AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) => Opacity(
                  opacity: _fadeAnimation.value,
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
                        'No hay asignaturas disponibles',
                        style: TextStyle(
                          color: colors.onSurface.withOpacity(0.7),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _loadSubjects(),
            child: AnimationLimiter(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: subjects.length,
                itemBuilder: (context, index) {
                  final subject = subjects[index];
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 500),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: InkWell(
                            onTap: () => _showSubjectDetails(context, subject),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Hero(
                                        tag: 'search_subject_${subject.id}',
                                        child: Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: colors.primaryContainer,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              subject.nombre.substring(0, 2).toUpperCase(),
                                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                color: colors.onPrimaryContainer,
                                                fontWeight: FontWeight.bold,
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
                                              subject.nombre,
                                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.person,
                                                  size: 16,
                                                  color: colors.primary,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    '${subject.profesor?.nombre ?? 'No asignado'} ${subject.profesor?.apellidos ?? ''}',
                                                    style: TextStyle(
                                                      color: colors.onSurfaceVariant,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    subject.descripcion,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildEnrollButton(subject),
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
          );
        },
      ),
    );
  }

  void _showSubjectDetails(BuildContext context, dynamic subject) async {
    final accessCode = await EnrollmentDialog.show(context, subject.nombre);
    
    if (accessCode != null && mounted) {
      _enrollInSubject(
        context, 
        subject,
        accessCode,
      );
    }
  }

  Future<void> _enrollInSubject(BuildContext context, dynamic subject, String accessCode) async {
    try {
      final token = _authProvider?.token;
      final userId = _authProvider?.currentUser?.id;
      
      if (token == null || userId == null) {
        throw Exception('No hay sesión activa');
      }

      await _enrollmentProvider?.enrollInSubject(
        userId.toString(),
        subject.id.toString(),
        accessCode,
        token,
      );

      if (!mounted) return;

      // Recargar las asignaturas del usuario
      await context.read<SubjectsProvider>().loadSubjects(
        userId.toString(),
        _authProvider!.currentUser!.tipoUsuario,
        token,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Te has inscrito correctamente'),
          backgroundColor: Colors.green,
        ),
      );

      // Volver a la página de inicio
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 