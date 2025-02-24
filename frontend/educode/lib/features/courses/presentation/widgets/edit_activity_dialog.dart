import 'package:flutter/material.dart';
import '../../domain/models/activity_model.dart';

class EditActivityDialog extends StatefulWidget {
  final ActivityModel activity;

  const EditActivityDialog({
    super.key,
    required this.activity,
  });

  @override
  State<EditActivityDialog> createState() => _EditActivityDialogState();
}

class _EditActivityDialogState extends State<EditActivityDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _parametersController;
  late DateTime _dueDate;
  late TimeOfDay _dueTime;
  String? _selectedLanguage;

  final _programmingLanguages = [
    'Python',
    'JavaScript',
    'Java',
    'C++',
    'C',
    'C#',
    'TypeScript',
    'Dart',
    'Kotlin',
    'Swift',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.activity.titulo);
    _descriptionController = TextEditingController(text: widget.activity.descripcion);
    _parametersController = TextEditingController(text: widget.activity.parametrosEvaluacion ?? '');
    _selectedLanguage = widget.activity.lenguajeProgramacion;
    _dueDate = widget.activity.fechaEntrega;
    _dueTime = TimeOfDay.fromDateTime(widget.activity.fechaEntrega);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _parametersController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dueDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _dueTime.hour,
        _dueTime.minute,
      ));
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime,
    );
    if (picked != null) {
      setState(() {
        _dueTime = picked;
        _dueDate = DateTime(
          _dueDate.year,
          _dueDate.month,
          _dueDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Actividad'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Por favor ingrese un título';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Lenguaje de programación (opcional)',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedLanguage,
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Sin lenguaje específico'),
                    ),
                    ..._programmingLanguages.map((String language) {
                      return DropdownMenuItem<String>(
                        value: language,
                        child: Text(language),
                      );
                    }).toList(),
                  ],
                  onChanged: (String? value) {
                    setState(() => _selectedLanguage = value);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _parametersController,
                  decoration: const InputDecoration(
                    labelText: 'Parámetros a valorar (opcional)',
                    border: OutlineInputBorder(),
                    helperText: 'Escribe los aspectos específicos a evaluar en el código',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _selectDate(context),
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          'Fecha: ${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _selectTime(context),
                        icon: const Icon(Icons.access_time),
                        label: Text(
                          'Hora: ${_dueTime.format(context)}',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'titulo': _titleController.text,
                'descripcion': _descriptionController.text,
                'fecha_entrega': DateTime(
                  _dueDate.year,
                  _dueDate.month,
                  _dueDate.day,
                  _dueTime.hour,
                  _dueTime.minute,
                ).toUtc().toIso8601String(),
                'lenguaje_programacion': _selectedLanguage,
                'parametros_evaluacion': _parametersController.text.isEmpty 
                    ? null 
                    : _parametersController.text,
              });
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
} 