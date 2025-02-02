class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? token;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      token: json['token'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'email': email,
      'role': role,
      'token': token,
    };
  }
} 