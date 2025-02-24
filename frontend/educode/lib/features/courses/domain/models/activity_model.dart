class ActivityModel {
  final int id;
  final String titulo;
  final String descripcion;
  final DateTime fechaCreacion;
  final DateTime fechaEntrega;
  final int asignaturaId;
  final String? lenguajeProgramacion;
  final String? parametrosEvaluacion;

  ActivityModel({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.fechaCreacion,
    required this.fechaEntrega,
    required this.asignaturaId,
    this.lenguajeProgramacion,
    this.parametrosEvaluacion,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      id: json['id'],
      titulo: json['titulo'],
      descripcion: json['descripcion'] ?? '',
      fechaCreacion: DateTime.parse(json['fecha_creacion']),
      fechaEntrega: DateTime.parse(json['fecha_entrega']),
      asignaturaId: json['asignatura_id'],
      lenguajeProgramacion: json['lenguaje_programacion'],
      parametrosEvaluacion: json['parametros_evaluacion'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'titulo': titulo,
      'descripcion': descripcion,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_entrega': fechaEntrega.toIso8601String(),
      'asignatura_id': asignaturaId,
      'lenguaje_programacion': lenguajeProgramacion,
      'parametros_evaluacion': parametrosEvaluacion,
    };
  }
} 