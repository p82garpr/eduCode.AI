import 'package:educode/features/auth/presentation/widgets/edit_profile_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:educode/features/auth/presentation/providers/auth_provider.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final colors = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          Stack(
            alignment: Alignment.center,
            children: [
              // Avatar y nombre
              CircleAvatar(
                radius: 50,
                backgroundColor: colors.primary,
                child: Text(
                  user?.nombre.substring(0, 1).toUpperCase() ?? '',
                  style: const TextStyle(
                    fontSize: 40,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Botón de editar
              Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const EditProfileDialog(),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  style: IconButton.styleFrom(
                    backgroundColor: colors.primaryContainer,
                    foregroundColor: colors.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${user?.nombre} ${user?.apellidos}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            user?.tipoUsuario ?? '',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colors.primary,
                ),
          ),
          const SizedBox(height: 32),
          // Información del usuario
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              elevation: 2,
              child: Column(
                children: [
                  _buildInfoTile(
                    context,
                    icon: Icons.email,
                    title: 'Correo electrónico',
                    subtitle: user?.email ?? '',
                  ),
                  const Divider(height: 1),
                  _buildInfoTile(
                    context,
                    icon: Icons.school,
                    title: 'Rol',
                    subtitle: user?.tipoUsuario ?? '',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.grey,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
    );
  }
} 