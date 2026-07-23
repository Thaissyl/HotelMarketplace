import 'package:flutter/material.dart';

String maintenanceStatusLabel(String status) {
  return switch (status) {
    'InProgress' => 'In Progress',
    _ => status,
  };
}

String maintenanceIssueType(String description) {
  final normalized = description.toLowerCase();
  if (normalized.contains('faucet') ||
      normalized.contains('water') ||
      normalized.contains('toilet') ||
      normalized.contains('plumb')) {
    return 'Plumbing';
  }
  if (normalized.contains('light') ||
      normalized.contains('power') ||
      normalized.contains('electric')) {
    return 'Electrical';
  }
  if (normalized.contains('air condition') ||
      normalized.contains('ac ') ||
      normalized.contains('cool')) {
    return 'Air Conditioning';
  }
  if (normalized.contains('door') ||
      normalized.contains('lock') ||
      normalized.contains('key')) {
    return 'Door and Lock';
  }
  if (normalized.contains('smoke') ||
      normalized.contains('alarm') ||
      normalized.contains('detector')) {
    return 'Safety Equipment';
  }
  return 'General Maintenance';
}

String maintenanceIssueTitle(String description) {
  final normalized = description.trim();
  if (normalized.isEmpty) {
    return 'Issue Report';
  }

  final firstLine = normalized.split(RegExp(r'[.\n]')).first.trim();
  final shortened =
      firstLine.length <= 48 ? firstLine : '${firstLine.substring(0, 48)}...';
  return shortened
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map(
        (word) => '${word.substring(0, 1).toUpperCase()}'
            '${word.length > 1 ? word.substring(1) : ''}',
      )
      .join(' ');
}

IconData maintenanceIssueIcon(String description) {
  return switch (maintenanceIssueType(description)) {
    'Plumbing' => Icons.plumbing_outlined,
    'Electrical' => Icons.lightbulb_outline,
    'Air Conditioning' => Icons.air_outlined,
    'Door and Lock' => Icons.lock_outline,
    'Safety Equipment' => Icons.sensors_outlined,
    _ => Icons.build_outlined,
  };
}
