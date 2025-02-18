class Submission {
  final int id;
  final DateTime fechaEntrega;
  final String? comentarios;
  final double? calificacion;
  final int actividadId;
  final int alumnoId;
  final String? nombreArchivo;
  final String? tipoImagen;
  final String? textoOcr;
  String? nombreAlumno;

  Submission({
    required this.id,
    required this.fechaEntrega,
    this.comentarios,
    this.calificacion,
    required this.actividadId,
    required this.alumnoId,
    this.nombreArchivo,
    this.tipoImagen,
    this.textoOcr,
    this.nombreAlumno,
  });

  factory Submission.fromJson(Map<String, dynamic> json) {
    return Submission(
      id: json['id'],
      fechaEntrega: DateTime.parse(json['fecha_entrega']),
      comentarios: json['comentarios'],
      calificacion: json['calificacion']?.toDouble(),
      actividadId: json['actividad_id'],
      alumnoId: json['alumno_id'],
      nombreArchivo: json['nombre_archivo'],
      tipoImagen: json['tipo_imagen'],
      nombreAlumno: json['alumno']?['nombre'],
      textoOcr: json['texto_ocr'],
    );
  }
} 