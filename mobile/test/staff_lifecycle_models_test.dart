import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_marketplace_mobile/features/operations/domain/operations_models.dart';

void main() {
  test('parses staff assignment lifecycle state', () {
    final member = HotelStaffMember.fromJson({
      'userAccountId': 'user-1',
      'assignmentId': 'assignment-1',
      'hotelId': 'hotel-1',
      'email': 'reception@example.com',
      'fullName': 'Reception Staff',
      'phoneNumber': '0901234567',
      'role': 'Receptionist',
      'status': 'Active',
      'isAssignmentActive': false,
      'assignedAtUtc': '2026-07-19T10:00:00Z',
    });

    expect(member.assignmentId, 'assignment-1');
    expect(member.role, 'Receptionist');
    expect(member.isAssignmentActive, isFalse);
    expect(member.assignedAtUtc.isUtc, isTrue);
  });

  test('serializes attach and single-purpose update requests', () {
    const attach = AttachStaffRequest(
      email: '  staff@example.com ',
      role: 'MaintenanceStaff',
    );
    const roleUpdate = UpdateStaffAssignmentRequest(role: 'Receptionist');
    const accessUpdate = UpdateStaffAssignmentRequest(isActive: true);

    expect(attach.toJson(), {
      'email': 'staff@example.com',
      'role': 'MaintenanceStaff',
    });
    expect(roleUpdate.toJson(), {'role': 'Receptionist'});
    expect(accessUpdate.toJson(), {'isActive': true});
  });
}
