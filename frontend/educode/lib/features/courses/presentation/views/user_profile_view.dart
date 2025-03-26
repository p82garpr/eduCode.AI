import 'package:educode/features/courses/presentation/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';

class UserProfileView extends StatelessWidget {
  final String userId;
  final String userType;

  const UserProfileView({
    super.key,
    required this.userId,
    required this.userType,
  });

  // Función para generar un color basado en una cadena de texto
  Color _getColorFromString(String text) {
    // Generamos un hash a partir del texto
    final int hash = text.hashCode.abs();
    
    // Lista de colores base para elegir (colores azules/verdes que coinciden con la app)
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
    
    // Selecciona un color de la lista basado en el hash
    return baseColors[hash % baseColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final token = context.read<AuthProvider>().token;

    return Scaffold(
      appBar: AppBar(
        title: Text('Perfil de ${userType == 'Profesor' ? 'Profesor' : 'Estudiante'}'),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 0,
      ),
      body: FutureBuilder(
        future: context.read<ProfileProvider>().getUserProfile(userId, token!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final user = snapshot.data!;
          final subjects = userType == 'Profesor' 
              ? user.asignaturasImpartidas 
              : user.asignaturasInscritas;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado del perfil con gradiente
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.primary,
                        colors.primary.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadow.withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.onPrimary,
                          border: Border.all(
                            color: colors.onPrimary,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.shadow.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            user.nombre[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 40,
                              color: colors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${user.nombre} ${user.apellidos}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.onPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colors.onPrimary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          userType,
                          style: TextStyle(
                            color: colors.onPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Tarjeta de información de contacto
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: colors.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.email_outlined,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                        title: Text(
                          'Correo electrónico',
                          style: TextStyle(
                            color: colors.onSurface.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                        subtitle: InkWell(
                          onTap: () async {
                            final Uri emailLaunchUri = Uri(
                              scheme: 'mailto',
                              path: user.email,
                            );
                            
                            if (await canLaunchUrl(emailLaunchUri)) {
                              await launchUrl(emailLaunchUri);
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('No se pudo abrir el cliente de correo'),
                                  ),
                                );
                              }
                            }
                          },
                          child: Text(
                            user.email,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                              color: colors.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        trailing: Icon(
                          Icons.open_in_new,
                          size: 16,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Sección de asignaturas
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.book_outlined,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      userType == 'Profesor' 
                          ? 'Asignaturas que imparte' 
                          : 'Asignaturas inscritas',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                if (subjects.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 48,
                          color: colors.primary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          userType == 'Profesor'
                              ? 'No imparte ninguna asignatura actualmente'
                              : 'No está inscrito en ninguna asignatura',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colors.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: subjects.length,
                    itemBuilder: (context, index) {
                      final subject = subjects[index];
                      // Generamos un color basado en el nombre
                      final color = _getColorFromString(subject.nombre);
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: colors.outline.withOpacity(0.2),
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                color.withOpacity(0.2),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, 
                              vertical: 8,
                            ),
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  subject.nombre.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              subject.nombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              subject.descripcion,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
} 