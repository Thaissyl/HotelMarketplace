import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hotel_marketplace_mobile/core/storage/secure_session_storage.dart';
import 'package:hotel_marketplace_mobile/features/operations/application/operations_providers.dart';
import 'package:hotel_marketplace_mobile/features/operations/application/selected_hotel_controller.dart';
import 'package:hotel_marketplace_mobile/features/operations/domain/operations_models.dart';
import 'package:hotel_marketplace_mobile/features/operations/presentation/manager_overview_tab.dart';

void main() {
  testWidgets(
    'SCR-014 renders the complete owner manager dashboard without layout errors',
    (tester) async {
      const hotelId = 'hotel-1';
      final sessionStorage = _MemorySessionStorage();

      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            selectedHotelControllerProvider.overrideWith(
              (ref) => SelectedHotelController(
                sessionStorage: sessionStorage,
                availableHotelIds: const [hotelId, 'stale-token-hotel'],
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
            home: Scaffold(
              body: ManagerOverviewTab(
                hotelId: hotelId,
                roles: ['PropertyOwner'],
                onOpenSection: null,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Hotel Selector'), findsOneWidget);
      expect(find.text('Demo Central Hotel'), findsOneWidget);
      expect(find.text('Hotel Summary Cards'), findsOneWidget);
      expect(find.text('Operational Metrics'), findsOneWidget);

      final selector = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>),
      );
      expect(selector.items, hasLength(1));

      await tester.scrollUntilVisible(
        find.text('Navigation Menu'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Navigation Menu'), findsOneWidget);
      expect(find.text('Hotel Profile'), findsOneWidget);
      expect(find.text('Rooms'), findsAtLeastNWidgets(1));
      expect(find.text('Staff'), findsOneWidget);
      expect(find.text('Front Desk'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
    },
  );
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
  _MemorySessionStorage() : super(const FlutterSecureStorage());

  String? _selectedHotelId;

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
}
