import 'package:flutter/material.dart';
import '../../domain/models/activity_model.dart';
import '../../domain/models/enrolled_student_model.dart';
import '../../domain/models/submission_model.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
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
            

            // como archivos adjuntos, comentarios adicionales, etc.
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