import 'package:educode/features/auth/presentation/providers/auth_provider.dart';
import 'package:educode/features/courses/presentation/providers/activity_provider.dart';
import 'package:educode/features/courses/presentation/providers/submission_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:educode/features/courses/domain/models/submission_model.dart';
import 'package:educode/features/courses/domain/models/activity_model.dart';
import 'package:educode/features/courses/presentation/providers/subjects_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async' show unawaited;
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentActivitySubmissionPage extends StatefulWidget {
  const StudentActivitySubmissionPage({super.key});

  @override
  State<StudentActivitySubmissionPage> createState() => _StudentActivitySubmissionPageState();
}

class _StudentActivitySubmissionPageState extends State<StudentActivitySubmissionPage> {
  final _formKey = GlobalKey<FormState>();
  final _solutionController = TextEditingController();
  bool _isLoading = false;
  Submission? _existingSubmission;
  ActivityModel? _activity;
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  bool _processingImage = false;
  bool _isTextExpanded = true;
  bool _isProcessingOcr = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  String _getSubmissionStatus() {
    if (_existingSubmission == null) return 'No entregado';
    if (_existingSubmission?.calificacion == null) return 'Pendiente de evaluación';
    return 'Calificación: ${_existingSubmission!.calificacion!.toStringAsFixed(1)}';
  }

  Color _getStatusColor(BuildContext context) {
    final theme = Theme.of(context);
    if (_existingSubmission == null) return theme.colorScheme.error;
    if (_existingSubmission?.calificacion == null) return theme.colorScheme.tertiary;
    return theme.colorScheme.primary;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      final activityId = args['activityId'] as int;
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.token;
      final alumnoId = authProvider.currentUser?.id;

      if (token == null || alumnoId == null) {
        throw Exception('No se encontró la información de autenticación necesaria');
      }

      debugPrint('Cargando actividad ID: $activityId');
      
      final activity = await context.read<ActivityProvider>().getActivity(activityId, token);
      debugPrint('Actividad cargada exitosamente: ${activity.titulo}');
      
      Submission? submission;
      try {
        submission = await context.read<SubmissionProvider>().getStudentSubmission2(
          int.parse(alumnoId), 
          activityId, 
          token
        );
        debugPrint('Entrega existente encontrada');
      } catch (e) {
        if (e.toString().contains('404')) {
          debugPrint('No hay entrega previa - esto es normal');
          submission = null;
        } else {
          rethrow;
        }
      }

      if (!mounted) return;

      setState(() {
        _activity = activity;
        _existingSubmission = submission;
        
        if (_existingSubmission != null) {
          _solutionController.text = _existingSubmission!.textoOcr ?? '';
        }
      });
    } catch (e) {
      debugPrint('Error al cargar datos: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar los datos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitSolution() async {
    if (!_formKey.currentState!.validate()) {
      debugPrint('Error: Validación del formulario fallida');
      return;
    }

    if (_activity == null) {
      debugPrint('Error: _activity es null');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se ha podido cargar la actividad')),
      );
      return;
    }

    if (_solutionController.text.isEmpty && _imageFile == null) {
      debugPrint('Error: No hay texto ni imagen para enviar');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Debe proporcionar una solución')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.token;
      
      if (token == null) {
        throw Exception('No se ha encontrado el token de autenticación');
      }

      final entrega = await context.read<SubmissionProvider>().submitActivity(
        _activity!.id,
        _solutionController.text,
        token,
        image: _imageFile,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Entrega realizada con éxito!'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _existingSubmission = entrega;
        _imageFile = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al realizar la entrega: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
          _processingImage = true;
        });

        // Aquí iría el procesamiento de la imagen si es necesario

        setState(() {
          _processingImage = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar la imagen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _isSubmissionAllowed() {
    if (_activity == null) return false;
    final now = DateTime.now();
    return _existingSubmission == null && now.isBefore(_activity!.fechaEntrega);
  }

  Future<void> _downloadImage() async {
    if (_existingSubmission == null || _existingSubmission!.nombreArchivo == null) return;

    try {
      setState(() => _isLoading = true);

      final token = context.read<AuthProvider>().token;
      if (token == null) throw Exception('No se encontró el token de autenticación');

      final url = await context.read<SubmissionProvider>().getSubmissionImageUrl(
        _existingSubmission!.id,
        token,
      );

      if (!mounted) return;

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw Exception('No se pudo abrir la URL');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al descargar la imagen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          _existingSubmission != null ? 'Detalles de la Entrega' : 'Nueva Entrega',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: colors.surface,
        elevation: 0,
      ),
      body: AnimationLimiter(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 600),
              childAnimationBuilder: (widget) => SlideAnimation(
                horizontalOffset: 50.0,
                child: FadeInAnimation(child: widget),
              ),
              children: [
                if (_activity != null) ...[
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colors.outline.withOpacity(0.2)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: colors.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.assignment_outlined,
                                  color: colors.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _activity!.titulo,
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Fecha límite: ${_formatDate(_activity!.fechaEntrega)}',
                                      style: TextStyle(
                                        color: DateTime.now().isAfter(_activity!.fechaEntrega)
                                            ? colors.error
                                            : colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (_activity!.descripcion.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              _activity!.descripcion,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getStatusColor(context).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _existingSubmission != null
                                      ? _existingSubmission!.calificacion != null
                                          ? Icons.check_circle
                                          : Icons.pending
                                      : Icons.error_outline,
                                  size: 16,
                                  color: _getStatusColor(context),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _getSubmissionStatus(),
                                  style: TextStyle(
                                    color: _getStatusColor(context),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_isSubmissionAllowed()) ...[
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tu solución',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _solutionController,
                            maxLines: null,
                            minLines: 5,
                            decoration: InputDecoration(
                              hintText: 'Escribe tu solución aquí...',
                              filled: true,
                              fillColor: colors.surfaceVariant.withOpacity(0.3),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: colors.outline),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: colors.outline.withOpacity(0.5)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: colors.primary, width: 2),
                              ),
                            ),
                            validator: (value) {
                              if ((value == null || value.isEmpty) && _imageFile == null) {
                                return 'Por favor, proporciona una solución o sube una imagen';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pickImage,
                                  icon: const Icon(Icons.image_outlined),
                                  label: const Text('Subir imagen'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _submitSolution,
                                  icon: const Icon(Icons.send_outlined),
                                  label: const Text('Entregar'),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_imageFile != null) ...[
                            const SizedBox(height: 16),
                            Card(
                              elevation: 0,
                              color: colors.surfaceVariant.withOpacity(0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: colors.outline.withOpacity(0.2)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    const Icon(Icons.image),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Imagen seleccionada: ${_imageFile!.path.split('/').last}',
                                        style: theme.textTheme.bodyMedium,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () => setState(() => _imageFile = null),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else if (_existingSubmission != null) ...[
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colors.outline.withOpacity(0.2)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tu entrega',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_existingSubmission!.textoOcr?.isNotEmpty ?? false) ...[
                              Text(
                                'Solución:',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colors.surfaceVariant.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: colors.outline.withOpacity(0.2),
                                  ),
                                ),
                                child: Text(
                                  _existingSubmission!.textoOcr!,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                            if (_existingSubmission!.nombreArchivo != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Imagen adjunta:',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colors.surfaceVariant.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: colors.outline.withOpacity(0.2),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.image_outlined,
                                          color: colors.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _existingSubmission!.nombreArchivo!,
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.download_outlined,
                                            color: colors.primary,
                                          ),
                                          onPressed: _downloadImage,
                                          tooltip: 'Descargar imagen',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colors.primaryContainer.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colors.outline.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_outlined,
                                    size: 20,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Entregado el ${_formatDate(_existingSubmission!.fechaEntrega)}',
                                    style: TextStyle(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: colors.onErrorContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'La fecha límite de entrega ha pasado',
                              style: TextStyle(
                                color: colors.onErrorContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _solutionController.dispose();
    super.dispose();
  }
} 