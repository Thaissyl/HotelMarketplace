import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_marketplace_mobile/core/storage/secure_session_storage.dart';
import 'package:hotel_marketplace_mobile/features/operations/application/selected_hotel_controller.dart';

void main() {
  test('adds and selects a hotel when the source list is fixed-length',
      () async {
    final sourceHotelIds = List<String>.of(
      const ['existing-hotel-id'],
      growable: false,
    );
    final storage = _MemorySessionStorage();
    final controller = SelectedHotelController(
      sessionStorage: storage,
      availableHotelIds: sourceHotelIds,
    );

    await controller.addAndSelectHotel('new-hotel-id');

    expect(controller.state.asData?.value, 'new-hotel-id');
    expect(storage.currentHotelId, 'new-hotel-id');
    expect(sourceHotelIds, const ['existing-hotel-id']);

    await controller.selectHotel('existing-hotel-id');
    expect(controller.state.asData?.value, 'existing-hotel-id');
  });
}

class _MemorySessionStorage extends SecureSessionStorage {
  _MemorySessionStorage() : super(const FlutterSecureStorage());

  String? currentHotelId;

  @override
  Future<String?> getCurrentHotelId() async => currentHotelId;

  @override
  Future<void> saveCurrentHotelId(String hotelId) async {
    currentHotelId = hotelId;
  }

  @override
  Future<void> clearCurrentHotelId() async {
    currentHotelId = null;
  }
}
