import '../../../shared/utils/app_formatters.dart';

enum HousekeepingTaskStatus {
  open('Open'),
  inProgress('InProgress'),
  inspectionRequired('InspectionRequired'),
  completed('Completed'),
  cancelled('Cancelled');

  const HousekeepingTaskStatus(this.apiValue);
  final String apiValue;
}

enum MaintenanceStatus {
  open('Open'),
  inProgress('InProgress'),
  resolved('Resolved'),
  released('Released'),
  cancelled('Cancelled');

  const MaintenanceStatus(this.apiValue);
  final String apiValue;
}

enum MaintenanceSeverity {
  low('Low'),
  medium('Medium'),
  high('High'),
  critical('Critical');

  const MaintenanceSeverity(this.apiValue);
  final String apiValue;
}

class RoomInventoryItem {
  const RoomInventoryItem({
    required this.id,
    required this.hotelId,
    required this.roomTypeId,
    required this.roomNumber,
    required this.status,
  });

  final String id;
  final String hotelId;
  final String roomTypeId;
  final String roomNumber;
  final String status;

  bool get isAvailable => status == 'Available';

  static RoomInventoryItem fromJson(Object? data) {
    final json = _asMap(data);
    return RoomInventoryItem(
      id: json['id']?.toString() ?? '',
      hotelId: json['hotelId']?.toString() ?? '',
      roomTypeId: json['roomTypeId']?.toString() ?? '',
      roomNumber: json['roomNumber']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }
}

class RoomTypeInventoryItem {
  const RoomTypeInventoryItem({
    required this.id,
    required this.name,
    required this.basePricePerNight,
  });

  final String id;
  final String name;
  final double basePricePerNight;

  static RoomTypeInventoryItem fromJson(Object? data) {
    final json = _asMap(data);
    return RoomTypeInventoryItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      basePricePerNight: (json['basePricePerNight'] as num?)?.toDouble() ?? 0,
    );
  }
}

class FrontDeskBookingResult {
  const FrontDeskBookingResult({
    required this.bookingId,
    required this.bookingCode,
    required this.status,
    required this.totalAmount,
    required this.guestFullName,
    required this.assignedRooms,
    required this.invoiceId,
  });

  final String bookingId;
  final String bookingCode;
  final String status;
  final double totalAmount;
  final String guestFullName;
  final List<AssignedRoomResult> assignedRooms;
  final String? invoiceId;

  static FrontDeskBookingResult fromJson(Object? data) {
    final json = _asMap(data);
    final rooms = json['assignedRooms'];
    return FrontDeskBookingResult(
      bookingId: json['bookingId']?.toString() ?? '',
      bookingCode: json['bookingCode']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      guestFullName: json['guestFullName']?.toString() ?? '',
      assignedRooms: rooms is List
          ? rooms.map(AssignedRoomResult.fromJson).toList(growable: false)
          : const <AssignedRoomResult>[],
      invoiceId: json['invoiceId']?.toString(),
    );
  }
}

class AssignedRoomResult {
  const AssignedRoomResult({
    required this.physicalRoomId,
    required this.roomNumber,
    required this.status,
  });

  final String physicalRoomId;
  final String roomNumber;
  final String status;

  static AssignedRoomResult fromJson(Object? data) {
    final json = _asMap(data);
    return AssignedRoomResult(
      physicalRoomId: json['physicalRoomId']?.toString() ?? '',
      roomNumber: json['roomNumber']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }
}

class HousekeepingTask {
  const HousekeepingTask({
    required this.id,
    required this.physicalRoomId,
    required this.roomNumber,
    required this.taskType,
    required this.status,
    required this.roomStatus,
    required this.createdAtUtc,
  });

  final String id;
  final String physicalRoomId;
  final String roomNumber;
  final String taskType;
  final String status;
  final String roomStatus;
  final DateTime createdAtUtc;

  static HousekeepingTask fromJson(Object? data) {
    final json = _asMap(data);
    return HousekeepingTask(
      id: json['id']?.toString() ?? '',
      physicalRoomId: json['physicalRoomId']?.toString() ?? '',
      roomNumber: json['roomNumber']?.toString() ?? '',
      taskType: json['taskType']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      roomStatus: json['roomStatus']?.toString() ?? '',
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc']?.toString() ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
    );
  }
}

class MaintenanceRequestItem {
  const MaintenanceRequestItem({
    required this.id,
    required this.physicalRoomId,
    required this.roomNumber,
    required this.description,
    required this.severity,
    required this.status,
    required this.roomStatus,
    required this.createdAtUtc,
  });

  final String id;
  final String physicalRoomId;
  final String roomNumber;
  final String description;
  final String severity;
  final String status;
  final String roomStatus;
  final DateTime createdAtUtc;

  String get displayCreatedAt => AppFormatters.displayDate(createdAtUtc);

  static MaintenanceRequestItem fromJson(Object? data) {
    final json = _asMap(data);
    return MaintenanceRequestItem(
      id: json['id']?.toString() ?? '',
      physicalRoomId: json['physicalRoomId']?.toString() ?? '',
      roomNumber: json['roomNumber']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      severity: json['severity']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      roomStatus: json['roomStatus']?.toString() ?? '',
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc']?.toString() ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
    );
  }
}

Map<String, dynamic> _asMap(Object? data) {
  if (data is Map<String, dynamic>) {
    return data;
  }

  if (data is Map) {
    return data.map((key, value) => MapEntry(key.toString(), value));
  }

  return const <String, dynamic>{};
}
