import 'package:flutter/foundation.dart';

enum AppFlavor {
  development,
  staging,
  production;

  static AppFlavor fromName(String value) {
    return switch (value.trim().toLowerCase()) {
      'staging' => AppFlavor.staging,
      'production' || 'prod' => AppFlavor.production,
      _ => AppFlavor.development,
    };
  }
}

class AppEnvironment {
  const AppEnvironment({
    required this.flavor,
    required this.apiBaseUrl,
  });

  final AppFlavor flavor;
  final String apiBaseUrl;

  static AppEnvironment resolve() {
    const configuredFlavor = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    );
    const configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');

    final apiBaseUrl = configuredApiBaseUrl.trim().isNotEmpty
        ? configuredApiBaseUrl
        : _defaultLocalApiBaseUrl();

    return AppEnvironment(
      flavor: AppFlavor.fromName(configuredFlavor),
      apiBaseUrl: _normalizeBaseUrl(apiBaseUrl),
    );
  }

  static String _defaultLocalApiBaseUrl() {
    if (kIsWeb) {
      return 'http://localhost:5080';
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'http://10.0.2.2:5080',
      TargetPlatform.iOS => 'http://localhost:5080',
      TargetPlatform.macOS => 'http://localhost:5080',
      TargetPlatform.windows => 'http://localhost:5080',
      TargetPlatform.linux => 'http://localhost:5080',
      TargetPlatform.fuchsia => 'http://localhost:5080',
    };
  }

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }

    return trimmed;
  }
}
