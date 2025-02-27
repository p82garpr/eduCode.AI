import 'package:educode/features/auth/presentation/pages/login_page.dart';
import 'package:educode/features/auth/presentation/views/profile_view.dart';
import 'package:educode/features/courses/presentation/views/subjects_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/subjects_provider.dart';
import '../widgets/create_subject_dialog.dart';
import '../views/search_courses_view.dart';
//import 'package:educode/features/courses/presentation/views/subject_detail_view.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser;
      final token = authProvider.token;
      
      if (user != null && token != null) {
        context.read<SubjectsProvider>().loadSubjects(
          user.id.toString(),
          user.tipoUsuario,
          token,
        );
      } else {
        if (kDebugMode) {
          print('Error: No hay token disponible');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isTeacher = user?.tipoUsuario == 'Profesor';

    final List<Widget> studentPages = [
      const CoursesView(),      // Mis cursos
      const SearchCoursesView(),// Buscar cursos
      const ProfileView(),      // Perfil
    ];

    final List<Widget> teacherPages = [
      const CoursesView(),      // Mis cursos
      const ProfileView(),      // Perfil
    ];

    return Scaffold(
      appBar: _selectedIndex == 0 ? null : AppBar(
        title: Text(
          _getTitle(isTeacher),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.onPrimary,
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
        ],
      ),
      body: isTeacher 
        ? teacherPages[_selectedIndex == 2 ? 1 : _selectedIndex]
        : studentPages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          backgroundColor: Theme.of(context).colorScheme.surface,
          indicatorColor: Theme.of(context).colorScheme.primaryContainer,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          height: 65,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          animationDuration: const Duration(milliseconds: 500),
          destinations: [
            NavigationDestination(
              icon: Icon(
                Icons.school_outlined,
                color: _selectedIndex == 0 
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              selectedIcon: Icon(
                Icons.school,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: 'Mis Cursos',
            ),
            if (!isTeacher)
              NavigationDestination(
                icon: Icon(
                  Icons.search_outlined,
                  color: _selectedIndex == 1 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                selectedIcon: Icon(
                  Icons.search,
                  color: Theme.of(context).colorScheme.primary,
                ),
                label: 'Buscar Cursos',
              ),
            NavigationDestination(
              icon: Icon(
                Icons.person_outline,
                color: _selectedIndex == (isTeacher ? 1 : 2)
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              selectedIcon: Icon(
                Icons.person,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: 'Perfil',
            ),
          ],
        ),
      ),
      floatingActionButton: isTeacher && _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () async {
                final result = await showDialog<Map<String, String>>(
                  context: context,
                  builder: (context) => const CreateSubjectDialog(),
                );

                if (result != null && context.mounted) {
                  final token = context.read<AuthProvider>().token;
                  if (token == null) return;

                  try {
                    if (kDebugMode) {
                      print('Intentando crear asignatura...');
                    } // Debug
                    
                    await context
                        .read<SubjectsProvider>()
                        .createSubject(result, token);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Asignatura creada correctamente'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (kDebugMode) {
                      print('Error en HomePage: $e');
                    } // Debug
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al crear la asignatura: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  String _getTitle(bool isTeacher) {
    if (isTeacher) {
      return _selectedIndex == 0 ? 'Mis Cursos' : 'Mi Perfil';
    } else {
      switch (_selectedIndex) {
        case 0:
          return 'Mis Cursos';
        case 1:
          return 'Buscar Cursos';
        case 2:
          return 'Mi Perfil';
        default:
          return 'EduCode';
      }
    }
  }
} 