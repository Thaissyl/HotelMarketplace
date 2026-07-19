import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_marketplace_mobile/features/operations/domain/operations_models.dart';

void main() {
  test('parses availability calendar contract', () {
    final calendar = AvailabilityCalendar.fromJson({
      'hotelId': 'hotel-1',
      'startDate': '2026-08-01',
      'endDate': '2026-08-03',
      'roomTypes': [
        {
          'id': 'type-1',
          'name': 'Deluxe King',
          'status': 'Active',
          'physicalRooms': [
            {'id': 'room-1', 'roomNumber': '101', 'status': 'Available'},
          ],
        },
      ],
      'entries': [
        {
          'id': 'entry-1',
          'roomTypeId': 'type-1',
          'physicalRoomId': 'room-1',
          'startDate': '2026-08-01',
          'endDate': '2026-08-02',
          'status': 'Blocked',
          'reason': 'Engineering inspection',
        },
      ],
      'activeCommitments': [
        {
          'bookingId': 'booking-1',
          'bookingCode': 'BK-001',
          'roomTypeId': 'type-1',
          'checkInDate': '2026-08-02',
          'checkOutDate': '2026-08-03',
          'roomCount': 1,
          'status': 'Confirmed',
          'assignedPhysicalRoomIds': ['room-1'],
        },
      ],
    });

    expect(calendar.hotelId, 'hotel-1');
    expect(calendar.roomTypes.single.name, 'Deluxe King');
    expect(calendar.roomTypes.single.physicalRooms.single.roomNumber, '101');
    expect(calendar.entries.single.reason, 'Engineering inspection');
    expect(calendar.activeCommitments.single.bookingCode, 'BK-001');
    expect(
      calendar.activeCommitments.single.assignedPhysicalRoomIds,
      ['room-1'],
    );
  });
}
