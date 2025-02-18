// To parse this JSON data, do
//
//     final subject = subjectFromJson(jsonString);

import 'dart:convert';

List<Subject> subjectFromJson(String str) => List<Subject>.from(json.decode(str).map((x) => Subject.fromJson(x)));

String subjectToJson(List<Subject> data) => json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class Subject {
    final int id;
    final String nombre;
    final String descripcion;
    final int profesorId;
    final Profesor profesor;
    final String? codigoAcceso;

    Subject({
        required this.id,
        required this.nombre,
        required this.descripcion,
        required this.profesorId,
        required this.profesor,
        this.codigoAcceso,
    });

    factory Subject.fromJson(Map<String, dynamic> json) {
        return Subject(
            id: json['id'],
            nombre: json['nombre'],
            descripcion: json['descripcion'],
            profesorId: json['profesor_id'],
            profesor: Profesor.fromJson(json['profesor']),
            codigoAcceso: json['codigo_acceso'],
        );
    }

    Map<String, dynamic> toJson() => {
        "id": id,
        "nombre": nombre,
        "descripcion": descripcion,
        "profesor_id": profesorId,
        "profesor": profesor.toJson(),
        "codigo_acceso": codigoAcceso,
    };
}

class Profesor {
    final int id;
    final String email;
    final String nombre;
    final String apellidos;
    final String tipoUsuario;

    Profesor({
        required this.id,
        required this.email,
        required this.nombre,
        required this.apellidos,
        required this.tipoUsuario,
    });

    factory Profesor.fromJson(Map<String, dynamic> json) {
        return Profesor(
            id: json['id'],
            email: json['email'],
            nombre: json['nombre'],
            apellidos: json['apellidos'],
            tipoUsuario: json['tipo_usuario'],
        );
    }

    Map<String, dynamic> toJson() => {
        "id": id,
        "email": email,
        "nombre": nombre,
        "apellidos": apellidos,
        "tipo_usuario": tipoUsuario,
    };
}
