import 'package:flutter/material.dart';
import '../../domain/models/submission_model.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../../core/config/app_config.dart';
import 'package:provider/provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SubmissionDetailDialog extends StatelessWidget {
  final Submission submission;
  final bool isTeacher;

  const SubmissionDetailDialog({
    super.key,
    required this.submission,
    required this.isTeacher,
  });

  static Future<T?> show<T>(BuildContext context, Submission submission, bool isTeacher) {
    return showGeneralDialog<T>(
      context: context,
      pageBuilder: (context, animation, secondaryAnimation) => SubmissionDetailDialog(
        submission: submission,
        isTeacher: isTeacher,
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 200),
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
    );
  }

  Future<void> _downloadImage(BuildContext context) async {
    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) {
        throw Exception('No se encontró el token de autenticación');
      }

      // Construir la URL para descargar la imagen
      final url = '${AppConfig.apiBaseUrl}/entregas/imagen/${submission.id}';

      // Realizar la petición HTTP con el token
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Obtener el directorio temporal
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/${submission.nombreArchivo ?? "imagen.jpg"}');
        
        // Guardar la imagen
        await file.writeAsBytes(response.bodyBytes);

        // Compartir el archivo
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Imagen de la entrega',
        );
      } else {
        throw Exception('Error al descargar la imagen: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al descargar la imagen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Dialog(
      backgroundColor: colors.surface,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.assignment_turned_in,
                      color: colors.primary,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Detalles de la entrega',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colors.onSurfaceVariant),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Flexible(
              child: SingleChildScrollView(
                child: AnimationLimiter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: AnimationConfiguration.toStaggeredList(
                      duration: const Duration(milliseconds: 375),
                      childAnimationBuilder: (widget) => SlideAnimation(
                        verticalOffset: 20,
                        child: FadeInAnimation(child: widget),
                      ),
                      children: [
                        // Información del estudiante
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.primaryContainer.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colors.outline.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: colors.primary,
                                child: Text(
                                  submission.nombreAlumno?.isNotEmpty == true
                                      ? submission.nombreAlumno![0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: colors.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      submission.nombreAlumno ?? 'Estudiante',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Entregado el ${_formatDate(submission.fechaEntrega)}',
                                      style: TextStyle(
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Calificación
                        if (isTeacher || submission.calificacion != null) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colors.surfaceVariant.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colors.outline.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _getGradeColor(colors, submission.calificacion).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _getGradeIcon(submission.calificacion),
                                    color: _getGradeColor(colors, submission.calificacion),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Calificación',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        submission.calificacion?.toStringAsFixed(1) ?? 'Pendiente de calificar',
                                        style: theme.textTheme.headlineSmall?.copyWith(
                                          color: _getGradeColor(colors, submission.calificacion),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Comentarios
                        if (submission.comentarios?.isNotEmpty ?? false) ...[
                          Text(
                            'Comentarios',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colors.surfaceVariant.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colors.outline.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              submission.comentarios!,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Archivo adjunto y OCR
                        if (submission.nombreArchivo != null) ...[
                          Text(
                            'Archivo adjunto',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colors.surfaceVariant.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colors.outline.withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: colors.primary.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.image_outlined,
                                        color: colors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            submission.nombreArchivo!,
                                            style: theme.textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Imagen adjunta',
                                            style: TextStyle(
                                              color: colors.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _downloadImage(context),
                                    icon: const Icon(Icons.download),
                                    label: const Text('Descargar imagen'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      backgroundColor: colors.primary,
                                      foregroundColor: colors.onPrimary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (submission.textoOcr?.isNotEmpty ?? false) ...[
                            const SizedBox(height: 24),
                            Text(
                              'Texto reconocido (OCR)',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colors.surfaceVariant.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colors.outline.withOpacity(0.2),
                                ),
                              ),
                              child: Text(
                                submission.textoOcr!,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: colors.error,
                  ),
                  label: Text(
                    'Cerrar',
                    style: TextStyle(color: colors.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _getGradeColor(ColorScheme colors, double? grade) {
    if (grade == null) return colors.outline;
    if (grade >= 9) return Colors.green;
    if (grade >= 7) return Colors.blue;
    if (grade >= 5) return Colors.orange;
    return Colors.red;
  }

  IconData _getGradeIcon(double? grade) {
    if (grade == null) return Icons.pending;
    if (grade >= 9) return Icons.star;
    if (grade >= 7) return Icons.thumb_up;
    if (grade >= 5) return Icons.check_circle;
    return Icons.cancel;
  }
} 