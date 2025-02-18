import 'package:educode/features/courses/presentation/pages/home_page.dart';
import 'package:educode/features/courses/presentation/providers/enrollment_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../courses/presentation/providers/subjects_provider.dart';



class SearchCoursesView extends StatefulWidget {
  const SearchCoursesView({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SearchCoursesViewState createState() => _SearchCoursesViewState();
}

class _SearchCoursesViewState extends State<SearchCoursesView> {
  Future<List<dynamic>>? _subjectsFuture;
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey = GlobalKey<ScaffoldMessengerState>();
  AuthProvider? _authProvider;
  SubjectsProvider? _subjectsProvider;
  EnrollmentProvider? _enrollmentProvider;

  @override
  void initState() {
    super.initState();
    // Ya no llamamos a _loadSubjects aquí
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _subjectsProvider = Provider.of<SubjectsProvider>(context, listen: false);
    _enrollmentProvider = Provider.of<EnrollmentProvider>(context, listen: false);
    _loadSubjects(); // Movemos la carga aquí
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

    if (isEnrolled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              size: 16,
              color: Colors.green,
            ),
            const SizedBox(width: 4),
            Text(
              'Matriculado',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: () => _showSubjectDetails(context, subject),
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Matricularme'),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldKey,
      child: Scaffold(
        body: FutureBuilder<List<dynamic>>(
          future: _subjectsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
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
              return const Center(
                child: Text('No hay asignaturas disponibles'),
              );
            }

            return RefreshIndicator(
              onRefresh: () async => _loadSubjects(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: subjects.length,
                itemBuilder: (context, index) {
                  final subject = subjects[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: InkWell(
                      onTap: () => _showSubjectDetails(context, subject),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    subject.nombre,
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                ),
                                Container(
                                  constraints: const BoxConstraints(maxWidth: 120),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Código: ${subject.id}',
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              subject.descripcion,
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.person,
                                        size: 16,
                                        color: Theme.of(context).colorScheme.secondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Profesor: ${subject.profesor?.nombre ?? 'No asignado'}',
                                          style: Theme.of(context).textTheme.bodySmall,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _buildEnrollButton(subject),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _showSubjectDetails(BuildContext context, dynamic subject) {
    final subjectsProvider = context.read<SubjectsProvider>();
    final isEnrolled = subjectsProvider.subjects.any((s) => s.id == subject.id);
    final TextEditingController accessCodeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(subject.nombre),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Código: ${subject.id}'),
              const SizedBox(height: 8),
              Text('Descripción: ${subject.descripcion}'),
              const SizedBox(height: 8),
              Text('Profesor: ${subject.profesor?.nombre ?? 'No asignado'}'),
              if (!isEnrolled) ...[
                const SizedBox(height: 16),
                const Text(
                  'Para matricularte en esta asignatura, introduce el código de acceso proporcionado por el profesor:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: accessCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Código de acceso',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          if (!isEnrolled)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _enrollInSubject(
                  context, 
                  subject,
                  accessCodeController.text.trim(),
                );
              },
              child: const Text('Matricularme'),
            ),
        ],
      ),
    );
  }

  Future<void> _enrollInSubject(BuildContext context, dynamic subject, String accessCode) async {
    final token = _authProvider?.token;
    final userId = _authProvider?.currentUser?.id;
    
    if (token == null || userId == null || _enrollmentProvider == null || _subjectsProvider == null) {
      _scaffoldKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('No hay sesión activa'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (accessCode.isEmpty) {
      _scaffoldKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('El código de acceso es requerido'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Primero realizamos la matriculación
      await _enrollmentProvider!.enrollInSubject(
        userId.toString(),
        subject.id.toString(),
        accessCode,
        token,
      );

      // Actualizamos el provider de asignaturas
      await _subjectsProvider!.loadSubjects(userId.toString(), 'alumno', token);

      if (!mounted) return;

      // Mostramos el mensaje de éxito usando el key del ScaffoldMessenger
      _scaffoldKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('¡Matriculación exitosa!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navegamos a la página principal
      if (!mounted) return;
      
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
        (route) => false,
      );

    } catch (e) {
      if (!mounted) return;
      _scaffoldKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Error al matricularse: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 