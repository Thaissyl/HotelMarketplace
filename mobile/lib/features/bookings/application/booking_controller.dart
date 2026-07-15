import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/core_providers.dart';
import '../data/booking_api.dart';
import '../domain/booking_models.dart';

final bookingApiProvider = Provider<BookingApi>((ref) {
  return BookingApi(ref.watch(apiClientProvider));
});

final bookingControllerProvider =
    StateNotifierProvider<BookingController, AsyncValue<Booking?>>((ref) {
  return BookingController(ref.watch(bookingApiProvider));
});

class BookingController extends StateNotifier<AsyncValue<Booking?>> {
  BookingController(this._bookingApi) : super(const AsyncData(null));

  final BookingApi _bookingApi;

  Future<Booking?> createBooking(CreateBookingRequest request) async {
    state = const AsyncLoading();

    try {
      final booking = await _bookingApi.createBooking(request);
      state = AsyncData(booking);
      return booking;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

  void reset() {
    state = const AsyncData(null);
  }
}
