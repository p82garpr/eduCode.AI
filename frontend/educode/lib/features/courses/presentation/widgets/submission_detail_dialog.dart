import 'package:flutter/material.dart';
import '../../domain/models/submission_model.dart';
import 'package:url_launcher/url_launcher.dart';

class SubmissionDetailDialog extends StatelessWidget {
  final Submission submission;
  final bool isTeacher;

  const SubmissionDetailDialog({
    super.key,
    required this.submission,
    required this.isTeacher,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Detalles de la entrega',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            
            // Información del estudiante
            Text(
              'Estudiante: ${submission.nombreAlumno}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            // Fecha de entrega
            Text(
              'Fecha de entrega: ${_formatDate(submission.fechaEntrega)}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),

            // Comentarios
            Text(
              'Comentarios:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  submission.comentarios ?? 'Sin comentarios',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),

              ),
            ),
            const SizedBox(height: 16),

            // Archivo adjunto y OCR
            if (submission.nombreArchivo != null) ...[
              Text(
                'Archivo adjunto:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Descargar archivo'),
                onPressed: () => _downloadFile(submission.nombreArchivo!, context),
              ),
              if (submission.textoOcr != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Texto reconocido (OCR):',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      submission.textoOcr!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 16),

            // Calificación
            if (isTeacher || submission.calificacion != null) ...[
              Text(
                'Calificación:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                submission.calificacion?.toString() ?? 'Sin calificar',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: submission.calificacion != null
                      ? submission.calificacion! >= 5
                          ? Colors.green
                          : Colors.red
                      : null,
                ),
              ),
            ],

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
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

  Future<void> _downloadFile(String url, BuildContext context) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'No se pudo abrir el archivo';
      }
    } catch (e) {
      debugPrint('Error al abrir el archivo: $e');
    }
  }
} 