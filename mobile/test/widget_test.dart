import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hotel_marketplace_mobile/app/app.dart';
import 'package:hotel_marketplace_mobile/core/config/app_environment.dart';
import 'package:hotel_marketplace_mobile/core/di/core_providers.dart';
import 'package:hotel_marketplace_mobile/core/network/api_client.dart';
import 'package:hotel_marketplace_mobile/core/storage/secure_session_storage.dart';

void main() {
  testWidgets('renders API connection shell', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appEnvironmentProvider.overrideWithValue(
            const AppEnvironment(
              flavor: AppFlavor.development,
              apiBaseUrl: 'http://localhost:5080',
            ),
          ),
          secureSessionStorageProvider.overrideWithValue(
            _FakeSecureSessionStorage(),
          ),
          apiClientProvider.overrideWithValue(_FakeApiClient()),
        ],
        child: const HotelMarketplaceApp(),
      ),
    );

    await tester.pump();

    expect(find.text('Hotel Marketplace'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(find.text('Home / Search Screen'), findsOneWidget);
    expect(find.byTooltip('Login'), findsOneWidget);
  });

  test('production environment rejects an insecure API URL', () {
    expect(
      () => AppEnvironment.fromValues(
        flavor: AppFlavor.production,
        apiBaseUrl: 'http://api.example.com',
      ),
      throwsArgumentError,
    );
  });

  test('development environment accepts and normalizes a local API URL', () {
    final environment = AppEnvironment.fromValues(
      flavor: AppFlavor.development,
      apiBaseUrl: 'http://10.0.2.2:5080/',
    );

    expect(environment.apiBaseUrl, 'http://10.0.2.2:5080');
  });
}

class _FakeSecureSessionStorage extends SecureSessionStorage {
  _FakeSecureSessionStorage() : super(const FlutterSecureStorage());

  @override
  Future<String?> getAccessToken() async {
    return null;
  }

  @override
  Future<UserSession?> getUserSession() async {
    return null;
  }

  @override
  Future<void> clearSession() async {}
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(Dio());

  @override
  Future<ApiHealthStatus> getHealthStatus() async {
    return const ApiHealthStatus(
      status: 'Healthy',
      checks: [],
    );
  }
}
