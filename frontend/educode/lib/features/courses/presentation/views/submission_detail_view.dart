import 'package:flutter/material.dart';
import '../../domain/models/activity_model.dart';
import '../../domain/models/enrolled_student_model.dart';
import '../../domain/models/submission_model.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/app_config.dart';

//TODO: Añadir la información de la entrega
class SubmissionDetailView extends StatelessWidget {
  final Submission submission;
  final EnrolledStudent student;
  final ActivityModel activity;

  const SubmissionDetailView({
    super.key,
    required this.submission,
    required this.student,
    required this.activity,
  });

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _downloadImage(BuildContext context) async {
    if (submission.nombreArchivo == null) return;

    final url = '${AppConfig.apiBaseUrl}/entregas/download/${submission.id}';
    
    try {
      if (!await launchUrl(Uri.parse(url))) {
        throw 'No se pudo abrir el archivo';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar el archivo: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de entrega'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información de la actividad
            Text(
              activity.titulo,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              activity.descripcion,
              style: theme.textTheme.bodyLarge,
            ),
            const Divider(height: 32),
            
            // Información del estudiante
            ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  student.nombre.isNotEmpty ? student.nombre[0].toUpperCase() : '?',
                  style: TextStyle(color: theme.colorScheme.onPrimary),
                ),
              ),
              title: Text(
                '${student.nombre} ${student.apellidos}'.trim(),
                style: theme.textTheme.titleMedium,
              ),
              subtitle: Text(
                student.email,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const Divider(height: 32),
            
            // Información de la entrega
            Text(
              'Información de la entrega',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _InfoRow(
              label: 'Fecha de entrega:',
              value: _formatDate(submission.fechaEntrega),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: 'Estado:',
              value: submission.calificacion != null ? 'Calificado' : 'No calificado',
            ),
            if (submission.calificacion != null) ...[
              const SizedBox(height: 8),
              _InfoRow(
                label: 'Calificación:',
                value: submission.calificacion!.toStringAsFixed(1),
              ),
            ],
            if (submission.comentarios != null && submission.comentarios!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Comentarios:',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(submission.comentarios!),
            ],
            
            // Añadir sección de archivo adjunto
            if (submission.nombreArchivo != null) ...[
              const SizedBox(height: 24),
              Text(
                'Archivo adjunto',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.outline.withOpacity(0.5)),
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
                            submission.nombreArchivo!,
                            style: theme.textTheme.bodyLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _downloadImage(context),
                        icon: const Icon(Icons.download),
                        label: const Text('Descargar imagen'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: colors.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }
} 