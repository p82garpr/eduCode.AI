import 'package:flutter/material.dart';

class CreateActivityDialog extends StatefulWidget {
  const CreateActivityDialog({super.key});

  @override
  State<CreateActivityDialog> createState() => _CreateActivityDialogState();
}

class _CreateActivityDialogState extends State<CreateActivityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _dueTime = TimeOfDay.now();
  final _parametersController = TextEditingController();
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
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _parametersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 400,
          maxHeight: 600,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Nueva actividad',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Título',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
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
                          maxLines: 5,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingrese una descripción';
                            }
                            return null;
                          },
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
                            helperText: 'Escribe los aspectos específicos a evaluar en la solucion del problema',
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Fecha y hora de entrega',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              InkWell(
                                onTap: () async {
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
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        color: Theme.of(context).colorScheme.primary,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Fecha',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          Text(
                                            '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Divider(
                                height: 1,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              InkWell(
                                onTap: () async {
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
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        color: Theme.of(context).colorScheme.primary,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Hora',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          Text(
                                            _dueTime.format(context),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        final dueDateTime = DateTime(
                          _dueDate.year,
                          _dueDate.month,
                          _dueDate.day,
                          _dueTime.hour,
                          _dueTime.minute,
                        );
                        
                        // Asegurarnos de que la fecha está en UTC y tiene el formato correcto
                        final utcDueDate = dueDateTime.toUtc();
                        
                        Navigator.pop(context, {
                          'titulo': _titleController.text,
                          'descripcion': _descriptionController.text,
                          'fecha_entrega': utcDueDate.toIso8601String(),
                          'lenguaje_programacion': _selectedLanguage,
                          'parametros_evaluacion': _parametersController.text.isEmpty 
                              ? null 
                              : _parametersController.text,
                        });
                      }
                    },
                    child: const Text('Crear'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
} 