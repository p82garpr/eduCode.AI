import 'dart:io';

import 'package:educode/features/courses/presentation/providers/activity_provider.dart';
import 'package:educode/features/courses/presentation/providers/enrollment_provider.dart';
import 'package:educode/features/courses/presentation/providers/submission_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/models/activity_model.dart';
import '../../domain/models/enrolled_student_model.dart';
import '../../domain/models/submission_model.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/submission_detail_dialog.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';







class ActivitySubmissionsView extends StatefulWidget {
  final ActivityModel activity;
  final int subjectId;

  const ActivitySubmissionsView({
    super.key,
    required this.activity,
    required this.subjectId,
  });

  @override
  State<ActivitySubmissionsView> createState() => _ActivitySubmissionsViewState();
}

class _ActivitySubmissionsViewState extends State<ActivitySubmissionsView> {
  List<EnrolledStudent>? _students;
  Map<int, Submission>? _submissions;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final token = context.read<AuthProvider>().token;
      if (token == null) return;

      // Cargar estudiantes y entregas en paralelo
      final results = await Future.wait([
        context.read<EnrollmentProvider>().getEnrolledStudents(widget.subjectId, token),
        context.read<SubmissionProvider>().getActivitySubmissions(widget.activity.id, token),
      ]);

      if (mounted) {
        setState(() {
          _students = results[0] as List<EnrolledStudent>;
          final submissions = results[1] as List<Submission>;
          // Crear un mapa de alumnoId -> Submission para fácil acceso
          _submissions = {
            for (var submission in submissions) submission.alumnoId: submission
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildSubmissionsHeader() {
    if (_students == null) return const SizedBox.shrink();

    final totalStudents = _students!.length;
    final totalSubmissions = _submissions?.length ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Entregas: $totalSubmissions/$totalStudents',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: totalStudents > 0 ? totalSubmissions / totalStudents : 0,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(height: 8),
          Text(
            'Fecha límite: ${_formatDate(widget.activity.fechaEntrega)}',
            style: TextStyle(
              color: _isOverdue(widget.activity.fechaEntrega)
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.activity.titulo),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Exportar entregas',
            onPressed: () => _downloadCsv(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error: $_error',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: Column(
                    children: [
                      _buildSubmissionsHeader(),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _students?.length ?? 0,
                          itemBuilder: (context, index) {
                            final student = _students![index];
                            final submission = _submissions?[student.id];
                            final hasSubmission = submission != null;

                            return ListTile(
                              leading: CircleAvatar(
                                child: Text(student.nombre[0].toUpperCase()),
                              ),
                              title: Text('${student.nombre} ${student.apellidos}'),
                              subtitle: Text(
                                hasSubmission
                                    ? 'Entregado el ${_formatDate(submission.fechaEntrega)}'
                                    : 'No entregado',
                              ),
                              trailing: hasSubmission
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (submission.calificacion != null)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: Text(
                                              submission.calificacion!.toStringAsFixed(1),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        PopupMenuButton<String>(
                                          itemBuilder: (context) => [
                                            PopupMenuItem(
                                              value: 'grade',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.grade,
                                                    color: Theme.of(context).colorScheme.primary,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  const Text('Calificar'),
                                                ],
                                              ),
                                            ),
                                          ],
                                          onSelected: (value) {
                                            if (value == 'grade') {
                                              _showGradeDialog(submission);
                                            }
                                          },
                                        ),
                                      ],
                                    )
                                  : null,
                              onTap: () {
                                final submission = _submissions?[student.id];
                                if (submission != null) {
                                  _showSubmissionDetails(submission);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('El alumno aún no ha realizado la entrega'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  bool _isOverdue(DateTime dueDate) {
    return DateTime.now().isAfter(dueDate);
  }

  Future<void> _showGradeDialog(Submission submission) async {
    final controller = TextEditingController(
      text: submission.calificacion?.toString() ?? '',
    );

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Calificar entrega'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Calificación',
                hintText: 'Ingrese un número del 0 al 10',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final grade = double.tryParse(controller.text);
              if (grade != null && grade >= 0 && grade <= 10) {
                Navigator.pop(context, grade);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      try {
        final token = context.read<AuthProvider>().token;
        if (token == null) return;

        await context.read<SubmissionProvider>().gradeSubmission(
          submission.id,
          result,
          token,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Calificación guardada correctamente')),
          );
          _loadData(); // Recargar los datos
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al guardar la calificación: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showSubmissionDetails(Submission submission) async {
    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) return;

      final submissionDetails = await context
          .read<SubmissionProvider>()
          .getSubmissionDetails(submission.id, token);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => SubmissionDetailDialog(
            submission: submissionDetails,
            isTeacher: false,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar los detalles: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

//TODO: NO FUNCIONA LA DESCARGA DEL CSV - AHORA SI


  Future<void> _downloadCsv(BuildContext context) async {
    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) return;

      // Obtener el CSV usando el provider
      final csvString = await context.read<ActivityProvider>()
          .downloadActivityCsv(widget.activity.id, token);

      // Crear archivo temporal
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/entregas_${widget.activity.titulo}.csv');
      await file.writeAsString(csvString);

      // Compartir el archivo
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Entregas de ${widget.activity.titulo}',
      );

    } catch (e) {
      if (mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir el CSV: $e')),
        );
      }
    }
  }
} 