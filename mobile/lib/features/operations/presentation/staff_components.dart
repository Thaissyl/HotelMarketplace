import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../auth/domain/auth_models.dart';
import 'front_desk_components.dart';

String staffRoleLabel(String role) {
  return switch (role) {
    'HotelManager' => 'Hotel Manager',
    'Receptionist' => 'Receptionist',
    'HousekeepingStaff' => 'Housekeeping Staff',
    'MaintenanceStaff' => 'Maintenance Staff',
    _ => role,
  };
}

List<String> availableHotelStaffRoles({required bool isPropertyOwner}) {
  return [
    if (isPropertyOwner) UserRoleCode.hotelManager.apiValue,
    UserRoleCode.receptionist.apiValue,
    UserRoleCode.housekeepingStaff.apiValue,
    UserRoleCode.maintenanceStaff.apiValue,
  ];
}

class StaffPermissionSummary extends StatelessWidget {
  const StaffPermissionSummary({super.key, required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final permissions = _permissionsFor(role);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Permission Summary',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        FrontDeskPanel(
          child: Column(
            children: [
              for (var index = 0; index < permissions.length; index++) ...[
                if (index > 0) const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        child: Icon(permissions[index].$1, size: 20),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: Text(permissions[index].$2)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

List<(IconData, String)> _permissionsFor(String role) {
  return switch (role) {
    'HotelManager' => const [
        (Icons.key_outlined, 'View Dashboard: Yes'),
        (Icons.calendar_month_outlined, 'Manage Bookings: Yes'),
        (Icons.people_outline, 'Manage Guests: Yes'),
        (Icons.settings_outlined, 'Manage Rooms: Yes'),
        (Icons.description_outlined, 'View Reports: Yes'),
      ],
    'Receptionist' => const [
        (Icons.key_outlined, 'View Dashboard: Yes'),
        (Icons.calendar_month_outlined, 'Manage Bookings: Yes'),
        (Icons.people_outline, 'Manage Guests: Yes'),
        (Icons.settings_outlined, 'Manage Rooms: Limited'),
        (Icons.description_outlined, 'View Reports: No'),
      ],
    'HousekeepingStaff' => const [
        (Icons.key_outlined, 'View Dashboard: Yes'),
        (Icons.calendar_month_outlined, 'Manage Bookings: No'),
        (Icons.people_outline, 'Manage Guests: No'),
        (Icons.settings_outlined, 'Manage Rooms: Housekeeping'),
        (Icons.description_outlined, 'View Reports: No'),
      ],
    'MaintenanceStaff' => const [
        (Icons.key_outlined, 'View Dashboard: Yes'),
        (Icons.calendar_month_outlined, 'Manage Bookings: No'),
        (Icons.people_outline, 'Manage Guests: No'),
        (Icons.settings_outlined, 'Manage Rooms: Maintenance'),
        (Icons.description_outlined, 'View Reports: No'),
      ],
    _ => const [
        (Icons.visibility_outlined, 'View Assigned Hotel: Yes'),
      ],
  };
}
