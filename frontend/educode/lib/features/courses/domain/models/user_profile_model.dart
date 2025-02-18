import 'package:educode/features/courses/domain/models/subject_model.dart';

class UserProfileModel {
  final String id;
  final String nombre;
  final String apellidos;
  final String email;
  final String tipoUsuario;
  final List<Subject> asignaturasImpartidas;
  final List<Subject> asignaturasInscritas;

  UserProfileModel({
    required this.id,
    required this.nombre,
    required this.apellidos,
    required this.email,
    required this.tipoUsuario,
    this.asignaturasImpartidas = const [],
    this.asignaturasInscritas = const [],
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'].toString(),
      nombre: json['nombre'],
      apellidos: json['apellidos'],
      email: json['email'],
      tipoUsuario: json['tipo_usuario'],
      asignaturasImpartidas: (json['asignaturas_impartidas'] as List?)
          ?.map((e) => Subject.fromJson(e))
          .toList() ?? [],
      asignaturasInscritas: (json['asignaturas_inscritas'] as List?)
          ?.map((e) => Subject.fromJson(e))
          .toList() ?? [],
    );
  }
} 