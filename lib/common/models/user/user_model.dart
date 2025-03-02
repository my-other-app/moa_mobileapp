class UserModel{
  final String fullName;
  final String email;
  final String phone;

  UserModel({
    required this.fullName,
    required this.email,
    required this.phone,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      fullName: json['fullName'],
      email: json['email'],
      phone: json['phone'],
    );
  }

  Map<String, dynamic> toJson(UserModel user) {
    return {
      'fullName': user.fullName,
      'email': user.email,
      'phone': user.phone,
    };
  }
}