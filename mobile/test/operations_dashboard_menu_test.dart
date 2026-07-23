import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hotel_marketplace_mobile/core/network/api_client.dart';
import 'package:hotel_marketplace_mobile/core/network/session_invalidation_notifier.dart';
import 'package:hotel_marketplace_mobile/core/storage/secure_session_storage.dart';
import 'package:hotel_marketplace_mobile/features/auth/application/auth_controller.dart';
import 'package:hotel_marketplace_mobile/features/auth/data/auth_api.dart';
import 'package:hotel_marketplace_mobile/features/operations/application/operations_providers.dart';
import 'package:hotel_marketplace_mobile/features/operations/application/selected_hotel_controller.dart';
import 'package:hotel_marketplace_mobile/features/operations/domain/operations_models.dart';
import 'package:hotel_marketplace_mobile/features/operations/presentation/operations_dashboard_screen.dart';

void main() {
  testWidgets(
    'property owner menu opens hotel registration and labels housekeeping',
    (tester) async {
      await _pumpDashboard(tester, role: 'PropertyOwner');

      await tester.tap(find.byTooltip('Workspace menu'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(PopupMenuItem<String>, 'Housekeeping'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(PopupMenuItem<String>, 'Rooms'),
        findsNothing,
      );
      expect(
        find.widgetWithText(PopupMenuItem<String>, 'Register New Hotel'),
        findsOneWidget,
      );

      await tester.tap(
        find.widgetWithText(PopupMenuItem<String>, 'Register New Hotel'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hotel Registration Screen'), findsOneWidget);
      expect(find.text('Hotel Name'), findsOneWidget);
      expect(find.byTooltip('Back to dashboard'), findsOneWidget);
    },
  );

  testWidgets(
    'hotel manager menu does not expose hotel registration',
    (tester) async {
      await _pumpDashboard(tester, role: 'HotelManager');

      await tester.tap(find.byTooltip('Workspace menu'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(PopupMenuItem<String>, 'Housekeeping'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(PopupMenuItem<String>, 'Register New Hotel'),
        findsNothing,
      );
    },
  );
}

Future<void> _pumpDashboard(
  WidgetTester tester, {
  required String role,
}) async {
  const hotelId = 'hotel-1';
  final session = UserSession(
    userId: 'user-1',
    email: 'user@test.com',
    roles: [role],
    hotelIds: const [hotelId],
    expiresAtUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
  );
  final storage = _MemorySessionStorage(session);
  final invalidationNotifier = SessionInvalidationNotifier();
  final authController = AuthController(
    authApi: AuthApi(ApiClient(Dio())),
    sessionStorage: storage,
    sessionInvalidationNotifier: invalidationNotifier,
  );
  await authController.restoreSession();

  addTearDown(invalidationNotifier.dispose);
  await tester.binding.setSurfaceSize(const Size(420, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((ref) => authController),
        selectedHotelControllerProvider.overrideWith(
          (ref) => SelectedHotelController(
            sessionStorage: storage,
            availableHotelIds: const [hotelId],
          ),
        ),
        workingHotelsProvider.overrideWith(
          (ref) async => const [_demoHotel],
        ),
        physicalRoomsProvider.overrideWith(
          (ref, request) async => const [],
        ),
        frontDeskBookingsProvider.overrideWith(
          (ref, request) async => const [],
        ),
        housekeepingTasksProvider.overrideWith(
          (ref, request) async => const [],
        ),
        maintenanceRequestsProvider.overrideWith(
          (ref, request) async => const [],
        ),
      ],
      child: const MaterialApp(
        home: OperationsDashboardScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _demoHotel = WorkingHotel(
  id: 'hotel-1',
  name: 'Demo Central Hotel',
  city: 'Ho Chi Minh City',
  addressLine: 'Nguyen Hue Boulevard',
  contactEmail: 'hotel@test.com',
  contactPhone: '0900000099',
  description: 'Demo hotel for local role testing.',
  approvalStatus: 'Approved',
  publicationStatus: 'Published',
  requiresRoomInspection: true,
);

class _MemorySessionStorage extends SecureSessionStorage {
  _MemorySessionStorage(this.session) : super(const FlutterSecureStorage());

  final UserSession session;
  String? _selectedHotelId;

  @override
  Future<String?> getAccessToken() async {
    return 'test-token';
  }

  @override
  Future<UserSession?> getUserSession() async {
    return session;
  }

  @override
  Future<String?> getCurrentHotelId() async {
    return _selectedHotelId;
  }

  @override
  Future<void> saveCurrentHotelId(String hotelId) async {
    _selectedHotelId = hotelId;
  }

  @override
  Future<void> clearCurrentHotelId() async {
    _selectedHotelId = null;
  }

  @override
  Future<void> clearSession() async {}
}
