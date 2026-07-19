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

  Future<DemoPaymentResult> confirmDemoPayment({
    required String bookingId,
    required double amount,
  }) {
    return _apiClient.post<DemoPaymentResult>(
      '/api/bookings/$bookingId/demo-payment',
      data: {'amount': amount},
      decoder: DemoPaymentResult.fromJson,
    );
  }

  Future<BookingCancellationQuote> getCancellationQuote(String bookingId) {
    return _apiClient.get<BookingCancellationQuote>(
      '/api/bookings/$bookingId/cancellation-quote',
      decoder: BookingCancellationQuote.fromJson,
    );
  }

  Future<BookingCancellationResult> cancelBooking({
    required String bookingId,
    required String reason,
  }) {
    return _apiClient.post<BookingCancellationResult>(
      '/api/bookings/$bookingId/cancel',
      data: {'reason': reason.trim()},
      decoder: BookingCancellationResult.fromJson,
    );
  }
}
