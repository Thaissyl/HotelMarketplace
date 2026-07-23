import 'package:flutter/material.dart';

import '../domain/operations_models.dart';

String housekeepingTaskStatusLabel(String status) {
  return switch (status) {
    'Open' => 'Dirty',
    'InProgress' => 'Cleaning',
    'InspectionRequired' => 'Inspection',
    'Completed' => 'Cleaned',
    'Cancelled' => 'Cancelled',
    _ => status,
  };
}

String housekeepingTaskPriority(HousekeepingTask task) {
  if (task.status == 'Open' &&
      (!task.isAssigned ||
          DateTime.now().toUtc().difference(task.createdAtUtc) >=
              const Duration(hours: 2))) {
    return 'High';
  }

  return switch (task.status) {
    'InProgress' => 'Medium',
    'InspectionRequired' || 'Completed' => 'Low',
    _ => 'Medium',
  };
}

String housekeepingTaskTypeLabel(String taskType) {
  return switch (taskType) {
    'CheckoutCleaning' => 'Checkout cleaning',
    'PostMaintenanceCleaning' => 'Post-maintenance cleaning',
    'DeepCleaning' => 'Deep cleaning',
    'Inspection' => 'Inspection',
    _ => taskType,
  };
}

IconData housekeepingTaskIcon(HousekeepingTask task) {
  return switch (task.status) {
    'InProgress' => Icons.cleaning_services_outlined,
    'InspectionRequired' || 'Completed' => Icons.assignment_turned_in_outlined,
    _ => Icons.meeting_room_outlined,
  };
}

DateTime housekeepingTargetCompletion(HousekeepingTask task) {
  final duration = housekeepingTaskPriority(task) == 'High'
      ? const Duration(hours: 1)
      : const Duration(hours: 2);
  return task.createdAtUtc.add(duration);
}
