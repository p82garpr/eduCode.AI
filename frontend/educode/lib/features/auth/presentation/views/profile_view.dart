import 'package:educode/features/auth/presentation/widgets/edit_profile_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:educode/features/auth/presentation/providers/auth_provider.dart';
import 'package:educode/core/providers/theme_provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final themeProvider = context.watch<ThemeProvider>();
    final colors = Theme.of(context).colorScheme;

    return AnimationLimiter(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: AnimationConfiguration.toStaggeredList(
            duration: const Duration(milliseconds: 600),
            childAnimationBuilder: (widget) => SlideAnimation(
              horizontalOffset: 50.0,
              child: FadeInAnimation(child: widget),
            ),
            children: [
              const SizedBox(height: 32),
              // Sección de perfil
              Container(
                padding: const EdgeInsets.all(28),
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
                      color: colors.shadow.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Avatar con botón de edición
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Avatar con efecto de brillo
                        Hero(
                          tag: 'profile_avatar',
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.onPrimary,
                              border: Border.all(
                                color: colors.onPrimary,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.onPrimary.withOpacity(0.5),
                                  blurRadius: 15,
                                  spreadRadius: 1,
                                ),
                                BoxShadow(
                                  color: colors.shadow.withOpacity(0.2),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                user?.nombre.substring(0, 1).toUpperCase() ?? '',
                                style: TextStyle(
                                  fontSize: 46,
                                  color: colors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Botón de edición
                        Positioned(
                          right: 0,
                          bottom: 5,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.primaryContainer,
                              border: Border.all(
                                color: colors.onPrimary,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.shadow.withOpacity(0.2),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => const EditProfileDialog(),
                                );
                              },
                              icon: Icon(
                                Icons.edit,
                                color: colors.onPrimaryContainer,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '${user?.nombre} ${user?.apellidos}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colors.onPrimary,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: colors.onPrimary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Text(
                        user?.tipoUsuario ?? '',
                        style: TextStyle(
                          color: colors.onPrimary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              
              // Sección de información con diseño mejorado
              Card(
                elevation: 2,
                shadowColor: colors.shadow.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.email_outlined,
                            color: colors.onPrimaryContainer,
                            size: 26,
                          ),
                        ),
                        title: Text(
                          'Correo electrónico',
                          style: TextStyle(
                            color: colors.onSurface.withOpacity(0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            user?.email ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Divider(color: colors.outline.withOpacity(0.2), height: 32),
                      ),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.school_outlined,
                            color: colors.onPrimaryContainer,
                            size: 26,
                          ),
                        ),
                        title: Text(
                          'Rol',
                          style: TextStyle(
                            color: colors.onSurface.withOpacity(0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            user?.tipoUsuario ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Botón de tema mejorado
              GestureDetector(
                onTap: () => themeProvider.toggleTheme(),
                child: Card(
                  elevation: 3,
                  shadowColor: colors.shadow.withOpacity(0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: themeProvider.isDarkMode
                            ? [Colors.amber.shade700, Colors.orange.shade800]
                            : [Colors.indigo.shade700, Colors.blue.shade900],
                      ),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      title: Text(
                        themeProvider.isDarkMode ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
} 