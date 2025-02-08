class UserModel {
  final String id;
  final String nombre;
  final String apellidos;
  final String email;
  final String tipoUsuario;
  // ignore: non_constant_identifier_names
 


  UserModel({
    required this.id,
    required this.nombre,
    required this.apellidos,
    required this.email,
    required this.tipoUsuario,
    // ignore: non_constant_identifier_names
   
  });


  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'].toString(),
      nombre: json['nombre'],
      apellidos: json['apellidos'],
      email: json['email'],
      tipoUsuario: json['tipo_usuario'],
      // ignore: non_constant_identifier_names
    
    );


  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'apellidos': apellidos,
      'email': email,
      'tipo_usuario': tipoUsuario,
      // ignore: non_constant_identifier_names
    };


  }
} 