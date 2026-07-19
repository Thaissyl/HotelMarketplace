import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_marketplace_mobile/features/bookings/domain/booking_models.dart';
import 'package:hotel_marketplace_mobile/features/platform_admin/domain/platform_admin_models.dart';

void main() {
  test('serializes booking collection mode and parses confirmed booking', () {
    final request = CreateBookingRequest(
      hotelId: 'hotel-1',
      roomTypeId: 'room-type-1',
      checkInDate: DateTime(2026, 8, 1),
      checkOutDate: DateTime(2026, 8, 3),
      roomCount: 1,
      guestCount: 2,
      guestFullName: '  Test Guest  ',
      guestPhone: ' 0901234567 ',
      paymentMode: 'PayAtProperty',
    );

    expect(request.toJson(), containsPair('paymentMode', 'PayAtProperty'));
    expect(request.toJson(), containsPair('guestFullName', 'Test Guest'));

    final booking = Booking.fromJson({
      'id': 'booking-1',
      'bookingCode': 'BK-001',
      'hotelId': 'hotel-1',
      'roomTypeId': 'room-type-1',
      'checkInDate': '2026-08-01',
      'checkOutDate': '2026-08-03',
      'roomCount': 1,
      'guestCount': 2,
      'nights': 2,
      'unitPricePerNight': 125,
      'totalAmount': 250,
      'paymentMode': 'PayAtProperty',
      'status': 'Confirmed',
      'createdAtUtc': '2026-07-19T10:00:00Z',
      'paymentExpiresAtUtc': null,
      'guestFullName': 'Test Guest',
      'guestPhone': '0901234567',
    });

    expect(booking.paymentMode, 'PayAtProperty');
    expect(booking.status, 'Confirmed');
    expect(booking.paymentExpiresAtUtc, isNull);
    expect(booking.isPendingPayment, isFalse);
  });

  test('parses settlement evidence and immutable finance snapshots', () {
    final settlement = AdminSettlement.fromJson({
      'id': 'settlement-1',
      'hotelId': 'hotel-1',
      'hotelName': 'Central Hotel',
      'settlementType': 'HotelPayable',
      'expectedAmount': 225,
      'settledAmount': 225,
      'status': 'Settled',
      'adminNote': 'Verified by finance',
      'createdAtUtc': '2026-07-19T10:00:00Z',
      'settlementDateUtc': '2026-07-20T08:00:00Z',
      'reference': 'BANK-REF-001',
      'items': [
        {
          'id': 'item-1',
          'amount': 225,
          'status': 'Settled',
          'paymentMode': 'PlatformCollect',
          'bookingStatus': 'CheckedOut',
          'grossAmount': 250,
          'refundAmount': 0,
          'commissionAmount': 25,
        },
      ],
    });

    expect(settlement.settlementType, 'HotelPayable');
    expect(settlement.expectedAmount, 225);
    expect(settlement.settledAmount, 225);
    expect(settlement.reference, 'BANK-REF-001');
    expect(settlement.settlementDateUtc, DateTime.utc(2026, 7, 20, 8));
    expect(settlement.items.single.grossAmount, 250);
    expect(settlement.items.single.commissionAmount, 25);
  });
}
