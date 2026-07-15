import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureSessionStorage {
  SecureSessionStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const String _accessTokenKey = 'session.accessToken';
  static const String _refreshTokenKey = 'session.refreshToken';
  static const String _userSessionKey = 'session.user';
  static const String _currentHotelIdKey = 'session.currentHotelId';

  static SecureSessionStorage create() {
    const iosOptions = IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    );

    return SecureSessionStorage(
      const FlutterSecureStorage(
        iOptions: iosOptions,
      ),
    );
  }

  Future<String?> getAccessToken() {
    return _storage.read(key: _accessTokenKey);
  }

  Future<void> saveAccessToken(String accessToken) {
    return _storage.write(key: _accessTokenKey, value: accessToken);
  }

  Future<String?> getRefreshToken() {
    return _storage.read(key: _refreshTokenKey);
  }

  Future<void> saveRefreshToken(String refreshToken) {
    return _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<UserSession?> getUserSession() async {
    final rawValue = await _storage.read(key: _userSessionKey);
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(rawValue);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    return UserSession.fromJson(decoded);
  }

  Future<void> saveUserSession(UserSession session) {
    return _storage.write(
      key: _userSessionKey,
      value: jsonEncode(session.toJson()),
    );
  }

  Future<String?> getCurrentHotelId() {
    return _storage.read(key: _currentHotelIdKey);
  }

  Future<void> saveCurrentHotelId(String hotelId) {
    return _storage.write(key: _currentHotelIdKey, value: hotelId);
  }

  Future<void> clearCurrentHotelId() {
    return _storage.delete(key: _currentHotelIdKey);
  }

  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _userSessionKey),
      _storage.delete(key: _currentHotelIdKey),
    ]);
  }
}

class UserSession {
  const UserSession({
    required this.userId,
    required this.email,
    required this.roles,
    required this.hotelIds,
    required this.expiresAtUtc,
  });

  final String userId;
  final String email;
  final List<String> roles;
  final List<String> hotelIds;
  final DateTime expiresAtUtc;

  static UserSession fromJson(Map<String, dynamic> json) {
    return UserSession(
      userId: json['userId']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      roles: _stringList(json['roles']),
      hotelIds: _stringList(json['hotelIds']),
      expiresAtUtc: DateTime.tryParse(
            json['expiresAtUtc']?.toString() ?? '',
          )?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'email': email,
      'roles': roles,
      'hotelIds': hotelIds,
      'expiresAtUtc': expiresAtUtc.toUtc().toIso8601String(),
    };
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }

    return value.map((item) => item.toString()).toList(growable: false);
  }
}
