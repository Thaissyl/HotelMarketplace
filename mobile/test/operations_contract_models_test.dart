import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_marketplace_mobile/features/operations/domain/operations_models.dart';

void main() {
  test('serializes owner hotel registration contract', () {
    const request = RegisterHotelRequest(
      name: ' Riverside Hotel ',
      city: ' Ho Chi Minh City ',
      addressLine: ' 10 River Street ',
      contactEmail: ' owner@example.com ',
      contactPhone: '0901234567',
      description: ' Guest-facing description ',
    );

    expect(request.toJson(), {
      'name': 'Riverside Hotel',
      'city': 'Ho Chi Minh City',
      'addressLine': '10 River Street',
      'contactEmail': 'owner@example.com',
      'contactPhone': '0901234567',
      'description': 'Guest-facing description',
    });
  });

  test('parses and serializes complete hotel content contract', () {
    final content = HotelContent.fromJson({
      'images': [
        {'imageUrl': 'https://example.com/hotel.jpg', 'displayOrder': 0},
      ],
      'amenities': [
        {'code': 'WIFI', 'name': 'Free Wi-Fi', 'type': 'Connectivity'},
      ],
      'cancellationPolicy': {
        'name': 'Flexible',
        'freeCancellationHours': 24,
        'refundPercentage': 100,
        'description': 'Full refund before the deadline.',
      },
    });

    expect(content.images.single.displayOrder, 0);
    expect(content.amenities.single.code, 'WIFI');
    expect(content.cancellationPolicy?.refundPercentage, 100);

    final request = UpdateHotelContentRequest(
      images: content.images,
      amenities: content.amenities,
      cancellationPolicy: content.cancellationPolicy,
    );
    expect(
      (request.toJson()['cancellationPolicy']
          as Map<String, dynamic>)['refundPercentage'],
      100,
    );
  });

  test('parses front desk guest count and payment collection contracts', () {
    final booking = FrontDeskBookingSummary.fromJson({
      'bookingId': 'booking-1',
      'bookingCode': 'BK-2026-0001',
      'hotelId': 'hotel-1',
      'status': 'CheckedIn',
      'paymentMode': 'PayAtProperty',
      'source': 'Online',
      'checkInDate': '2026-07-23',
      'checkOutDate': '2026-07-25',
      'guestCount': 3,
      'totalAmount': 300,
      'guestFullName': 'Test Guest',
      'guestPhone': '0912345678',
      'roomTypeId': 'room-type-1',
      'roomTypeName': 'Deluxe Room',
      'roomQuantity': 1,
      'nights': 2,
      'assignedRooms': const [],
      'createdAtUtc': '2026-07-20T08:00:00Z',
    });
    final collection = PaymentCollectionSummary.fromJson({
      'bookingId': 'booking-1',
      'bookingCode': 'BK-2026-0001',
      'paymentMode': 'PayAtProperty',
      'expectedAmount': 300,
      'collectedAmount': 100,
      'remainingBalance': 200,
      'status': 'PartiallyCollected',
      'collections': [
        {
          'id': 'collection-1',
          'amount': 100,
          'balanceBefore': 300,
          'balanceAfter': 200,
          'method': 'Cash',
          'reference': 'CASH-001',
          'status': 'Recorded',
          'collectedAtUtc': '2026-07-23T09:00:00Z',
        },
      ],
    });

    expect(booking.guestCount, 3);
    expect(collection.remainingBalance, 200);
    expect(collection.collections.single.reference, 'CASH-001');
  });
}
