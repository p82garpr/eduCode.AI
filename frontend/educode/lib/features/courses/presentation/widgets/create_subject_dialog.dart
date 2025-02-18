import 'package:educode/features/auth/presentation/providers/auth_provider.dart';
import 'package:educode/features/courses/presentation/providers/subjects_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


class CreateSubjectDialog extends StatefulWidget {
  const CreateSubjectDialog({super.key});

  @override
  State<CreateSubjectDialog> createState() => _CreateSubjectDialogState();
}

class _CreateSubjectDialogState extends State<CreateSubjectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _accessCodeController = TextEditingController();
  bool _obscureText = true;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _accessCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva asignatura'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Introduce el nombre de la asignatura',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor ingrese un nombre';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText: 'Introduce una descripción de la asignatura',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor ingrese una descripción';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _accessCodeController,
              decoration: InputDecoration(
                labelText: 'Código de acceso',
                hintText: 'Código para que los alumnos se inscriban',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                ),
              ),
              obscureText: _obscureText,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor ingrese un código de acceso';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => _handleSubmit(context),
          child: const Text('Crear'),
        ),
      ],
    );
  }

  Future<void> _handleSubmit(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      try {
        final authProvider = context.read<AuthProvider>();
        final subjectsProvider = context.read<SubjectsProvider>();
        final token = authProvider.token;
        final userId = authProvider.currentUser?.id;

        if (token == null || userId == null) {
          throw Exception('No hay sesión activa');
        }

        // Crear la asignatura
        await subjectsProvider.createSubject({
          'nombre': _nameController.text,
          'descripcion': _descriptionController.text,
          'codigo_acceso': _accessCodeController.text,
          'profesor_id': userId,
        }, token);

        if (!mounted) return;

        // Recargar la lista de asignaturas antes de cerrar el diálogo
        await subjectsProvider.loadSubjects(
          userId.toString(),
          'Profesor',
          token,
        );

        if (!mounted) return;

        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Asignatura creada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );

        // Cerrar el diálogo
        Navigator.of(context).pop();

      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear la asignatura: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 