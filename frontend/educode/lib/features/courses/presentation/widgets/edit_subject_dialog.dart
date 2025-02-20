import 'package:flutter/material.dart';
import '../../domain/models/subject_model.dart';

class EditSubjectDialog extends StatefulWidget {
  final Subject subject;

  const EditSubjectDialog({
    super.key,
    required this.subject,
  });

  @override
  State<EditSubjectDialog> createState() => _EditSubjectDialogState();
}

class _EditSubjectDialogState extends State<EditSubjectDialog> {
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _codigoAccesoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nombreController.text = widget.subject.nombre;
    _descripcionController.text = widget.subject.descripcion;
    _codigoAccesoController.text = '';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Asignatura'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'El nombre es requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'La descripción es requerida';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codigoAccesoController,
                decoration: const InputDecoration(
                  labelText: 'Código de Acceso',
                  border: OutlineInputBorder(),
                  helperText: 'Dejar vacío para mantener el actual',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              final Map<String, String> data = {
                'nombre': _nombreController.text,
                'descripcion': _descripcionController.text,
              };
              
              if (_codigoAccesoController.text.isNotEmpty) {
                data['codigo_acceso'] = _codigoAccesoController.text;
              }
              Navigator.pop(context, data);
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _codigoAccesoController.dispose();
    super.dispose();
  }
} 