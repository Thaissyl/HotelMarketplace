import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/app_environment.dart';
import 'core/di/core_providers.dart';
import 'core/storage/secure_session_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final environment = AppEnvironment.resolve();
  final secureSessionStorage = SecureSessionStorage.create();

  runApp(
    ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(environment),
        secureSessionStorageProvider.overrideWithValue(secureSessionStorage),
      ],
      child: const HotelMarketplaceApp(),
    ),
  );
}
