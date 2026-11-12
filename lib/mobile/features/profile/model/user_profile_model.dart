class UserProfileModel {
  final String oldPassword;
  final String newPassword;
  final String confirmPassword;

  // Konstruktor untuk inisialisasi model
  UserProfileModel({
    required this.oldPassword,
    required this.newPassword,
    required this.confirmPassword,
  });

  // Mengonversi model ini ke dalam bentuk map (untuk API)
  Map<String, dynamic> toMap() {
    return {
      'old_password': oldPassword,
      'new_password': newPassword,
      'confirm_password': confirmPassword,
    };
  }

  // Membuat objek UserProfileModel dari map (misalnya dari response API)
  factory UserProfileModel.fromMap(Map<String, dynamic> map) {
    return UserProfileModel(
      oldPassword: map['old_password'] ?? '',
      newPassword: map['new_password'] ?? '',
      confirmPassword: map['confirm_password'] ?? '',
    );
  }
}
