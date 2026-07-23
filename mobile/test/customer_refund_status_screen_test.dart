import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hotel_marketplace_mobile/app/theme/app_theme.dart';
import 'package:hotel_marketplace_mobile/features/bookings/domain/booking_models.dart';
import 'package:hotel_marketplace_mobile/features/bookings/presentation/customer_refund_status_screen.dart';

void main() {
  testWidgets(
    'SCR-013 renders refund icons, amounts, status, and customer note',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: CustomerRefundStatusScreen(booking: _refundBooking),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Customer Refund Status Screen'), findsOneWidget);
      expect(find.text('Refund Eligibility'), findsOneWidget);
      expect(find.text('Refund Status'), findsOneWidget);
      expect(find.text('Requested Amount'), findsOneWidget);
      expect(find.text('Approved Amount'), findsOneWidget);
      expect(find.text('Pending Review'), findsOneWidget);
      expect(find.byIcon(Icons.verified_user_outlined), findsOneWidget);
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
      expect(
        find.byIcon(Icons.account_balance_wallet_outlined),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Customer Note'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Customer Note'), findsOneWidget);
      expect(
        find.textContaining('platform team will review'),
        findsOneWidget,
      );
    },
  );
}

final _refundBooking = Booking(
  id: 'booking-1',
  bookingCode: 'BKG-REFUND-001',
  hotelId: 'hotel-1',
  roomTypeId: 'room-type-1',
  checkInDate: DateTime.utc(2026, 8, 10),
  checkOutDate: DateTime.utc(2026, 8, 12),
  roomCount: 1,
  guestCount: 2,
  nights: 2,
  unitPricePerNight: 100,
  totalAmount: 200,
  paymentMode: 'PlatformCollect',
  status: 'Cancelled',
  createdAtUtc: DateTime.utc(2026, 7, 24),
  paymentExpiresAtUtc: null,
  guestFullName: 'Test Customer',
  guestPhone: '0900000001',
  refundStatus: 'PendingReview',
  refundRequestedAmount: 160,
  refundApprovedAmount: 0,
  hotelName: 'Saigon Central Hotel',
  roomTypeName: 'Deluxe Room',
);
