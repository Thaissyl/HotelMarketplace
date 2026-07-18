import '../../../core/network/api_client.dart';
import '../domain/booking_models.dart';

class BookingApi {
  BookingApi(this._apiClient);

  final ApiClient _apiClient;

  Future<Booking> createBooking(CreateBookingRequest request) {
    return _apiClient.post<Booking>(
      '/api/bookings',
      data: request.toJson(),
      decoder: Booking.fromJson,
    );
  }

  Future<List<Booking>> getMyBookings() {
    return _apiClient.get<List<Booking>>(
      '/api/bookings/my',
      decoder: (data) {
        if (data is! List) {
          return const <Booking>[];
        }

        return data.map(Booking.fromJson).toList(growable: false);
      },
    );
  }

  Future<PaymentResult> simulatePaymentSuccess(String bookingId) {
    return _apiClient.post<PaymentResult>(
      '/api/bookings/$bookingId/simulate-payment-success',
      decoder: PaymentResult.fromJson,
    );
  }
}
