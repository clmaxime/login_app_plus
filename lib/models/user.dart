class User {
  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
  });
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final int role;
  factory User.fromJson(Map<String, dynamic> json) {
    if (json['id'] is! int ||
        json['firstName'] is! String ||
        json['lastName'] is! String ||
        json['email'] is! String ||
        json['role'] is! int ||
        (json['firstName'] as String).isEmpty ||
        (json['lastName'] as String).isEmpty) {
      throw const FormatException('Invalid profile');
    }
    return User(
      id: json['id'] as int,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      email: json['email'] as String,
      role: json['role'] as int,
    );
  }
  String get fullName => '$firstName $lastName';
  String get roleLabel => switch (role) {
    1 => 'Administrateur',
    2 => 'Utilisateur',
    _ => 'Rôle $role',
  };
}
