

class EnrolledStudent {

  final String nombre;
  final String apellidos;
  final String email;
  final String tipoUsuario;
  final int id;

  EnrolledStudent({
    
    required this.nombre,
    required this.apellidos,
    required this.email,
    required this.tipoUsuario,
    required this.id,
  });



  factory EnrolledStudent.fromJson(Map<String, dynamic> json) {
    return EnrolledStudent(
      nombre: json['nombre'],
      apellidos: json['apellidos'],
      email: json['email'],
      tipoUsuario: json['tipo_usuario'],
      id: json['id'],
    );

  }
} 