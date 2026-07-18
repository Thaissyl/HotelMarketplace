class CustomerProfile {
  const CustomerProfile({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.phoneNumber,
  });

  final String userId;
  final String email;
  final String fullName;
  final String? phoneNumber;

  static CustomerProfile fromJson(Object? data) {
    final json = _asMap(data);
    return CustomerProfile(
      userId: json['userId']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString(),
    );
  }
}

class UpdateCustomerProfileRequest {
  const UpdateCustomerProfileRequest({
    required this.fullName,
    required this.phoneNumber,
  });

  final String fullName;
  final String? phoneNumber;

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName.trim(),
      'phoneNumber': phoneNumber?.trim(),
    };
  }
}

class ChangeCustomerPasswordRequest {
  const ChangeCustomerPasswordRequest({
    required this.currentPassword,
    required this.newPassword,
    required this.confirmNewPassword,
  });

  final String currentPassword;
  final String newPassword;
  final String confirmNewPassword;

  Map<String, dynamic> toJson() {
    return {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
      'confirmNewPassword': confirmNewPassword,
    };
  }
}

Map<String, dynamic> _asMap(Object? data) {
  if (data is Map<String, dynamic>) {
    return data;
  }

  if (data is Map) {
    return data.map((key, value) => MapEntry(key.toString(), value));
  }

  return const <String, dynamic>{};
}
