class ActivityModel {
  final int id;
  final String titulo;
  final String descripcion;
  final DateTime fechaEntrega;
  final DateTime fechaCreacion;
  final int asignaturaId;

  ActivityModel({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.fechaEntrega,
    required this.fechaCreacion,
    required this.asignaturaId,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      id: json['id'],
      titulo: json['titulo'],
      descripcion: json['descripcion'],
      fechaEntrega: DateTime.parse(json['fecha_entrega']),
      fechaCreacion: DateTime.parse(json['fecha_creacion']),
      asignaturaId: json['asignatura_id'],
    );
  }
} 