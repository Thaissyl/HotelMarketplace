import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_marketplace_mobile/features/auth/presentation/auth_form_validators.dart';
import 'package:hotel_marketplace_mobile/features/customer/application/customer_state.dart';

void main() {
  test('parses durable saved hotel and notification contracts', () {
    final savedHotel = SavedHotel.fromJson({
      'hotelId': 'hotel-1',
      'name': 'Riverside Hotel',
      'city': 'Da Nang',
      'addressLine': '1 River Street',
      'minimumPricePerNight': 125,
      'savedAtUtc': '2026-07-19T12:00:00Z',
    });
    final notification = CustomerNotification.fromJson({
      'id': 'notification-1',
      'eventType': 'BookingConfirmed',
      'message': 'Booking HM-100 is confirmed.',
      'createdAtUtc': '2026-07-19T12:00:00Z',
      'readAtUtc': null,
    });

    expect(savedHotel.id, 'hotel-1');
    expect(savedHotel.minimumPricePerNight, 125);
    expect(notification.title, 'Booking Confirmed');
    expect(notification.unread, isTrue);
  });

  test('authentication form rejects malformed customer input', () {
    expect(AuthFormValidators.email('string'), isNotNull);
    expect(AuthFormValidators.emailOrPhone('customer@example.com'), isNull);
    expect(AuthFormValidators.emailOrPhone('0912345678'), isNull);
    expect(AuthFormValidators.emailOrPhone('123456789'), isNotNull);
    expect(AuthFormValidators.phoneNumber('123456789'), isNotNull);
    expect(AuthFormValidators.phoneNumber('0912345678'), isNull);
    expect(AuthFormValidators.password('weak', strong: true), isNotNull);
    expect(AuthFormValidators.password('StrongPass1', strong: true), isNull);
  });
}
