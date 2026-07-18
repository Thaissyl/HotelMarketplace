import '../../../core/storage/secure_session_storage.dart';

enum UserRoleCode {
  customer('Customer'),
  propertyOwner('PropertyOwner'),
  hotelManager('HotelManager'),
  receptionist('Receptionist'),
  housekeepingStaff('HousekeepingStaff'),
  maintenanceStaff('MaintenanceStaff'),
  platformAdministrator('PlatformAdministrator');

  const UserRoleCode(this.apiValue);

  final String apiValue;

  static UserRoleCode fromApiValue(String value) {
    return UserRoleCode.values.firstWhere(
      (role) => role.apiValue == value,
      orElse: () => UserRoleCode.customer,
    );
  }
}

class LoginRequest {
  const LoginRequest({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;

  Map<String, dynamic> toJson() {
    return {
      'email': email.trim(),
      'password': password,
    };
  }
}

class RegisterRequest {
  const RegisterRequest({
    required this.email,
    required this.password,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
  });

  final String email;
  final String password;
  final String fullName;
  final String phoneNumber;
  final UserRoleCode role;

  Map<String, dynamic> toJson() {
    return {
      'email': email.trim(),
      'password': password,
      'fullName': fullName.trim(),
      'phoneNumber': phoneNumber.trim().isEmpty ? null : phoneNumber.trim(),
      'role': role.apiValue,
    };
  }
}

class AuthResponse {
  const AuthResponse({
    required this.userId,
    required this.email,
    required this.roles,
    required this.hotelIds,
    required this.accessToken,
    required this.expiresAtUtc,
  });

  final String userId;
  final String email;
  final List<UserRoleCode> roles;
  final List<String> hotelIds;
  final String accessToken;
  final DateTime expiresAtUtc;

  static AuthResponse fromJson(Object? data) {
    final json = _asMap(data);

    return AuthResponse(
      userId: json['userId']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      roles: _stringList(json['roles'])
          .map(UserRoleCode.fromApiValue)
          .toList(growable: false),
      hotelIds: _stringList(json['hotelIds']),
      accessToken: json['accessToken']?.toString() ?? '',
      expiresAtUtc:
          DateTime.tryParse(json['expiresAtUtc']?.toString() ?? '')?.toUtc() ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  UserSession toUserSession() {
    return UserSession(
      userId: userId,
      email: email,
      roles: roles.map((role) => role.apiValue).toList(growable: false),
      hotelIds: hotelIds,
      expiresAtUtc: expiresAtUtc,
    );
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

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }

  return value.map((item) => item.toString()).toList(growable: false);
}
