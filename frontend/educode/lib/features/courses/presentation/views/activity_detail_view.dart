import 'package:educode/features/courses/presentation/providers/submission_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/models/activity_model.dart';
import '../../domain/models/submission_model.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

class ActivityDetailView extends StatefulWidget {
  final ActivityModel activity;

  const ActivityDetailView({
    super.key,
    required this.activity,
  });

  @override
  State<ActivityDetailView> createState() => _ActivityDetailViewState();
}

class _ActivityDetailViewState extends State<ActivityDetailView> {
  bool _isLoading = true;
  String? _error;
  Submission? _submission;
  final _solutionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSubmission();
  }

  @override
  void dispose() {
    _solutionController.dispose();
    super.dispose();
  }

  Future<void> _loadSubmission() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final token = context.read<AuthProvider>().token;
      if (token == null) return;

      final submission = await context
          .read<SubmissionProvider>()
          .getStudentSubmission(widget.activity.id, token);

      if (mounted) {
        setState(() {
          _submission = submission;
          if (submission != null) {
            _solutionController.text = submission.textoOcr ?? '';
          }
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

  Future<void> _submitSolution() async {
    try {
      setState(() => _isLoading = true);

      final token = context.read<AuthProvider>().token;
      if (token == null) return;

      await context.read<SubmissionProvider>().submitActivity(
        widget.activity.id,
        _solutionController.text,
        token,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entrega realizada con éxito')),
        );
        _loadSubmission(); // Recargar la entrega
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al realizar la entrega: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.activity.titulo),
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
                        onPressed: _loadSubmission,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Detalles de la Actividad',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(widget.activity.descripcion),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.secondary,
                                  ),
                                  const SizedBox(width: 8),
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
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_submission != null) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tu Entrega',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text('Entregado el: ${_formatDate(_submission!.fechaEntrega)}'),
                                if (_submission!.calificacion != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Calificación: ${_submission!.calificacion!.toStringAsFixed(1)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                Text(
                                  'Solución:',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(_submission!.textoOcr ?? 'No hay texto OCR'),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nueva Entrega',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _solutionController,
                                  maxLines: 5,
                                  decoration: const InputDecoration(
                                    labelText: 'Tu solución',
                                    hintText: 'Escribe aquí tu solución...',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _submitSolution,
                                    child: const Text('Entregar'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
} 