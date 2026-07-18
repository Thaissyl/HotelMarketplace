import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/core_providers.dart';
import '../../../core/storage/secure_session_storage.dart';
import '../../auth/application/auth_controller.dart';

final selectedHotelControllerProvider =
    StateNotifierProvider<SelectedHotelController, AsyncValue<String?>>((ref) {
  return SelectedHotelController(
    sessionStorage: ref.watch(secureSessionStorageProvider),
    availableHotelIds:
        ref.watch(authControllerProvider).userSession?.hotelIds ??
            const <String>[],
  );
});

class SelectedHotelController extends StateNotifier<AsyncValue<String?>> {
  SelectedHotelController({
    required SecureSessionStorage sessionStorage,
    required List<String> availableHotelIds,
  })  : _sessionStorage = sessionStorage,
        _availableHotelIds = availableHotelIds,
        super(const AsyncLoading()) {
    load();
  }

  final SecureSessionStorage _sessionStorage;
  final List<String> _availableHotelIds;

  Future<void> load() async {
    final storedHotelId = await _sessionStorage.getCurrentHotelId();

    if (storedHotelId != null && _availableHotelIds.contains(storedHotelId)) {
      state = AsyncData(storedHotelId);
      return;
    }

    final fallbackHotelId =
        _availableHotelIds.isEmpty ? null : _availableHotelIds.first;

    if (fallbackHotelId == null) {
      await _sessionStorage.clearCurrentHotelId();
    } else {
      await _sessionStorage.saveCurrentHotelId(fallbackHotelId);
    }

    state = AsyncData(fallbackHotelId);
  }

  Future<void> selectHotel(String hotelId) async {
    if (!_availableHotelIds.contains(hotelId)) {
      return;
    }

    await _sessionStorage.saveCurrentHotelId(hotelId);
    state = AsyncData(hotelId);
  }
}
