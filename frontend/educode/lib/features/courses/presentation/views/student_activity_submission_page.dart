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
    return 'Entregado y evaluado';
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
      
      // Primero cargamos la actividad
      final activity = await context.read<ActivityProvider>().getActivity(activityId, token);
      debugPrint('Actividad cargada exitosamente: ${activity.titulo}');
      
      // Intentamos cargar la entrega, pero no es un error si no existe
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
          // No es un error, simplemente no hay entrega
          submission = null;
        } else {
          // Si es otro tipo de error, lo propagamos
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

    // Verificar la actividad
    if (_activity == null) {
      debugPrint('Error: _activity es null');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se ha podido cargar la actividad')),
      );
      return;
    }

    // Verificar que hay texto o imagen
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

      // Enviar la entrega
      final entrega = await context.read<SubmissionProvider>().submitActivity(
        _activity!.id,
        _solutionController.text,
        token,
        image: _imageFile,
      );

      if (!mounted) return;

      // Mostrar mensaje de éxito y volver atrás
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solución enviada correctamente')),
      );
      Navigator.pop(context);

      // Evaluar la entrega en segundo plano
      unawaited(
        context.read<SubmissionProvider>().evaluateSubmissionWithGemini(entrega.id, token).then((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entrega evaluada correctamente')),
          );
        }).catchError((e) {
          debugPrint('Error al evaluar con Gemini: $e');
          // No mostramos el error al usuario ya que es un proceso en segundo plano
        }),
      );

    } catch (e) {
      debugPrint('Error detallado en submitSolution: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar la solución: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
          _isProcessingOcr = true;
        });

        // Procesar la imagen con OCR
        // ignore: use_build_context_synchronously, unused_local_variable
        final provider = context.read<SubjectsProvider>();
        // ignore: use_build_context_synchronously
        final token = context.read<AuthProvider>().token;
        final text = await context.read<SubmissionProvider>().processImageOCR(_imageFile!, token ?? '');

        if (mounted) {
          setState(() {
            _solutionController.text = text;
            _isProcessingOcr = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingOcr = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar la imagen: $e')),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar imagen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(context);
                _getImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galería'),
              onTap: () {
                Navigator.pop(context);
                _getImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processOCR() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay imagen para procesar')),
      );
      return;
    }

    setState(() => _isProcessingOcr = true);
    
    try {
      final token = context.read<AuthProvider>().token;
      final text = await context.read<SubmissionProvider>().processImageOCR(_imageFile!, token ?? '');
      
      setState(() {
        _solutionController.text = text;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar la imagen: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingOcr = false);
      }
    }
  }

  bool _isSubmissionAllowed() {
    if (_activity == null) return false;
    
    // Depurar las fechas
    final now = DateTime.now();
    debugPrint('Fecha actual: $now');
    debugPrint('Fecha límite: ${_activity!.fechaEntrega}');
    
    // Si no hay entrega previa y estamos en fecha, permitir entrega
    return _existingSubmission == null && now.isBefore(_activity!.fechaEntrega);
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

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          _existingSubmission != null ? 'Detalles de la Entrega' : 'Nueva Entrega',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_activity != null) ...[
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: theme.shadowColor.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.assignment,
                                color: theme.colorScheme.primary,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _activity!.titulo,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.colorScheme.outline.withOpacity(0.1),
                              ),
                            ),
                            child: Text(
                              _activity!.descripcion,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                color: _activity!.fechaEntrega.isBefore(DateTime.now())
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Fecha límite: ${_formatDate(_activity!.fechaEntrega)}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: _activity!.fechaEntrega.isBefore(DateTime.now())
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    _existingSubmission != null 
                                        ? Icons.check_circle
                                        : Icons.pending_actions,
                                    color: _getStatusColor(context),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Estado: ${_getSubmissionStatus()}',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        color: _getStatusColor(context),
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_existingSubmission?.calificacion != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Nota: ${_existingSubmission!.calificacion!.toStringAsFixed(2)}/10',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (_existingSubmission?.calificacion != null) ...[
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.colorScheme.primary.withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_existingSubmission?.comentarios != null && 
                                    _existingSubmission!.comentarios!.isNotEmpty) ...[
                                  Text(
                                    'Feedback de la entrega:',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: theme.colorScheme.outline.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Text(
                                      _existingSubmission!.comentarios!,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (_existingSubmission == null) ...[
                          Center(
                            child: Column(
                              children: [
                                if (_imageFile != null) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      _imageFile!,
                                      height: 200,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _isProcessingOcr ? null : _processOCR,
                                    icon: const Icon(Icons.refresh),
                                    label: Text(_isProcessingOcr 
                                      ? 'Procesando imagen...' 
                                      : 'Re-procesar OCR'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                      backgroundColor: theme.colorScheme.secondary,
                                      foregroundColor: theme.colorScheme.onSecondary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                ElevatedButton.icon(
                                  onPressed: !_isSubmissionAllowed()
                                      ? null  // Deshabilitar si la fecha ha pasado
                                      : (_processingImage 
                                          ? null 
                                          : _showImageSourceDialog),
                                  icon: const Icon(Icons.camera_alt),
                                  label: Text(
                                    !_isSubmissionAllowed()
                                        ? 'Fecha límite superada'
                                        : (_processingImage 
                                            ? 'Procesando imagen...' 
                                            : 'Capturar o seleccionar imagen')
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: theme.colorScheme.onPrimary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
                                    disabledForegroundColor: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                if (!_isSubmissionAllowed()) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'La fecha límite de entrega ha pasado',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.error,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Texto extraído:',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _solutionController,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        filled: true,
                                        fillColor: theme.colorScheme.surface,
                                        hintText: 'El texto extraído aparecerá aquí',
                                      ),
                                      maxLines: 10,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Por favor, introduce una solución';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          ExpansionTile(
                            title: Text(
                              'Texto extraído',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            initiallyExpanded: _isTextExpanded,
                            onExpansionChanged: (expanded) {
                              setState(() => _isTextExpanded = expanded);
                            },
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextFormField(
                                      controller: _solutionController,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        filled: true,
                                        fillColor: theme.colorScheme.surface.withOpacity(0.5),
                                      ),
                                      maxLines: 10,
                                      readOnly: true,
                                    ),
                                    if (_existingSubmission?.calificacion == null) ...[
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () async {
                                            setState(() => _isLoading = true);
                                            try {
                                              final authProvider = context.read<AuthProvider>();
                                              await context.read<SubmissionProvider>().evaluateSubmissionWithGemini(
                                                _existingSubmission!.id,
                                                authProvider.token!,
                                              );
                                              // Recargar los datos después de evaluar
                                              await _loadData();
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Entrega evaluada correctamente'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            } catch (e) {
                                              debugPrint('Error al evaluar: $e');
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error al evaluar la entrega: $e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            } finally {
                                              if (mounted) {
                                                setState(() => _isLoading = false);
                                              }
                                            }
                                          },
                                          icon: const Icon(Icons.assessment),
                                          label: const Text('Evaluar entrega'),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            backgroundColor: theme.colorScheme.primary,
                                            foregroundColor: theme.colorScheme.onPrimary,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (_existingSubmission == null)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: (!_isSubmissionAllowed() || _isProcessingOcr)
                                  ? null
                                  : _submitSolution,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
                                disabledForegroundColor: theme.colorScheme.onSurfaceVariant,
                              ),
                              child: Text(
                                !_isSubmissionAllowed()
                                    ? 'Fecha límite superada'
                                    : (_isProcessingOcr 
                                        ? 'Procesando OCR...' 
                                        : 'Enviar Solución'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
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