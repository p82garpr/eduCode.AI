import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'dart:ui';

class CreateActivityDialog extends StatefulWidget {
  const CreateActivityDialog({super.key});

  static Future<Map<String, dynamic>?> show(BuildContext context) async {
    return showGeneralDialog<Map<String, dynamic>>(
      context: context,
      pageBuilder: (context, animation, secondaryAnimation) => const CreateActivityDialog(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 4 * curvedAnimation.value,
            sigmaY: 4 * curvedAnimation.value,
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(curvedAnimation),
            child: FadeTransition(
              opacity: curvedAnimation,
              child: child,
            ),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
    );
  }

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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _dueTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _dueTime) {
      setState(() {
        _dueTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return Dialog(
      backgroundColor: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Container(
        width: isSmallScreen ? size.width * 0.9 : 500,
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: size.height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.assignment_add,
                    color: colors.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Nueva actividad',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: AnimationLimiter(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: AnimationConfiguration.toStaggeredList(
                          duration: const Duration(milliseconds: 300),
                          childAnimationBuilder: (widget) => SlideAnimation(
                            verticalOffset: 20,
                            child: FadeInAnimation(child: widget),
                          ),
                          children: [
                            TextFormField(
                              controller: _titleController,
                              decoration: InputDecoration(
                                labelText: 'Título',
                                hintText: 'Ej: Ejercicio de bucles',
                                prefixIcon: Icon(Icons.title, color: colors.primary),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: colors.outline),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: colors.primary, width: 2),
                                ),
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
                              decoration: InputDecoration(
                                labelText: 'Descripción',
                                hintText: 'Describe los objetivos y requisitos de la actividad',
                                prefixIcon: Icon(Icons.description, color: colors.primary),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: colors.outline),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: colors.primary, width: 2),
                                ),
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
                              decoration: InputDecoration(
                                labelText: 'Lenguaje de programación (opcional)',
                                prefixIcon: Icon(Icons.code, color: colors.primary),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: colors.outline),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: colors.primary, width: 2),
                                ),
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
                              decoration: InputDecoration(
                                labelText: 'Parámetros a valorar (opcional)',
                                hintText: 'Ej: Eficiencia, legibilidad, documentación',
                                prefixIcon: Icon(Icons.checklist, color: colors.primary),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: colors.outline),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: colors.primary, width: 2),
                                ),
                                helperText: 'Aspectos a evaluar en la solución',
                              ),
                              maxLines: isSmallScreen ? 2 : 3,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Fecha y hora de entrega',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: colors.surfaceVariant.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colors.outline.withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                children: [
                                  ListTile(
                                    onTap: () => _selectDate(context),
                                    leading: Icon(
                                      Icons.calendar_today,
                                      color: colors.primary,
                                    ),
                                    title: const Text('Fecha de entrega'),
                                    subtitle: Text(
                                      '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                                      style: TextStyle(
                                        color: colors.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    trailing: Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                  Divider(color: colors.outline.withOpacity(0.2)),
                                  ListTile(
                                    onTap: () => _selectTime(context),
                                    leading: Icon(
                                      Icons.access_time,
                                      color: colors.primary,
                                    ),
                                    title: const Text('Hora de entrega'),
                                    subtitle: Text(
                                      _dueTime.format(context),
                                      style: TextStyle(
                                        color: colors.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    trailing: Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: colors.onSurfaceVariant,
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
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(color: colors.error),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                        
                        Navigator.pop(context, {
                          'titulo': _titleController.text,
                          'descripcion': _descriptionController.text,
                          'fecha_entrega': dueDateTime.toUtc().toIso8601String(),
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