import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_marketplace_mobile/features/bookings/domain/booking_models.dart';
import 'package:hotel_marketplace_mobile/features/bookings/presentation/pending_payment_screen.dart';

void main() {
  testWidgets('countdown timer is disposed when payment screen is removed',
      (tester) async {
    final now = DateTime.now().toUtc();
    final booking = Booking(
      id: 'booking-1',
      bookingCode: 'HM-100',
      hotelId: 'hotel-1',
      roomTypeId: 'room-type-1',
      checkInDate: now.add(const Duration(days: 1)),
      checkOutDate: now.add(const Duration(days: 2)),
      roomCount: 1,
      guestCount: 2,
      nights: 1,
      unitPricePerNight: 100,
      totalAmount: 100,
      paymentMode: 'PlatformCollect',
      status: 'PendingPayment',
      createdAtUtc: now,
      paymentExpiresAtUtc: now.add(const Duration(minutes: 15)),
      guestFullName: 'Test Guest',
      guestPhone: '0912345678',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: PendingPaymentScreen(booking: booking)),
      ),
    );
    expect(find.text('Confirm demo payment'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));

    expect(tester.takeException(), isNull);
  });
}
