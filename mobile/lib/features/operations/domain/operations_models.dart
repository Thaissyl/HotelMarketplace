import '../../../shared/utils/app_formatters.dart';

class WorkingHotel {
  const WorkingHotel({
    required this.id,
    required this.name,
    required this.city,
    required this.addressLine,
    required this.contactEmail,
    required this.contactPhone,
    required this.description,
    required this.approvalStatus,
    required this.publicationStatus,
    required this.requiresRoomInspection,
  });

  final String id;
  final String name;
  final String city;
  final String addressLine;
  final String contactEmail;
  final String contactPhone;
  final String description;
  final String approvalStatus;
  final String publicationStatus;
  final bool requiresRoomInspection;

  String get displayName => name.trim().isEmpty ? shortCode : name;

  String get subtitle {
    final parts = [
      if (city.trim().isNotEmpty) city.trim(),
      if (addressLine.trim().isNotEmpty) addressLine.trim(),
    ];

    return parts.isEmpty ? shortCode : parts.join(' - ');
  }

  String get shortCode {
    if (id.length <= 8) {
      return id;
    }

    return 'Hotel ${id.substring(0, 8)}';
  }

  static WorkingHotel fallback(String id) {
    return WorkingHotel(
      id: id,
      name: '',
      city: '',
      addressLine: '',
      contactEmail: '',
      contactPhone: '',
      description: '',
      approvalStatus: '',
      publicationStatus: '',
      requiresRoomInspection: true,
    );
  }

  static WorkingHotel fromJson(Object? data) {
    final json = _asMap(data);
    return WorkingHotel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      addressLine: json['addressLine']?.toString() ?? '',
      contactEmail: json['contactEmail']?.toString() ?? '',
      contactPhone: json['contactPhone']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      approvalStatus: json['approvalStatus']?.toString() ?? '',
      publicationStatus: json['publicationStatus']?.toString() ?? '',
      requiresRoomInspection: json['requiresRoomInspection'] as bool? ?? true,
    );
  }
}

class UpdateHotelProfileRequest {
  const UpdateHotelProfileRequest({
    required this.name,
    required this.city,
    required this.addressLine,
    required this.contactEmail,
    required this.contactPhone,
    required this.description,
    required this.requiresRoomInspection,
  });

  final String name;
  final String city;
  final String addressLine;
  final String contactEmail;
  final String contactPhone;
  final String description;
  final bool requiresRoomInspection;

  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      'city': city.trim(),
      'addressLine': addressLine.trim(),
      'contactEmail': contactEmail.trim(),
      'contactPhone': contactPhone.trim(),
      'description': description.trim().isEmpty ? null : description.trim(),
      'requiresRoomInspection': requiresRoomInspection,
    };
  }
}

class RegisterHotelRequest {
  const RegisterHotelRequest({
    required this.name,
    required this.city,
    required this.addressLine,
    required this.contactEmail,
    required this.contactPhone,
    required this.description,
  });

  final String name;
  final String city;
  final String addressLine;
  final String contactEmail;
  final String contactPhone;
  final String description;

  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      'city': city.trim(),
      'addressLine': addressLine.trim(),
      'contactEmail': contactEmail.trim(),
      'contactPhone': contactPhone.trim(),
      'description': description.trim().isEmpty ? null : description.trim(),
    };
  }
}

class HotelContent {
  const HotelContent({
    required this.images,
    required this.amenities,
    required this.cancellationPolicy,
  });

  final List<HotelContentImage> images;
  final List<HotelContentAmenity> amenities;
  final HotelCancellationPolicy? cancellationPolicy;

  static HotelContent fromJson(Object? data) {
    final json = _asMap(data);
    return HotelContent(
      images: (json['images'] as List? ?? const [])
          .map(HotelContentImage.fromJson)
          .toList(growable: false),
      amenities: (json['amenities'] as List? ?? const [])
          .map(HotelContentAmenity.fromJson)
          .toList(growable: false),
      cancellationPolicy: json['cancellationPolicy'] == null
          ? null
          : HotelCancellationPolicy.fromJson(json['cancellationPolicy']),
    );
  }
}

class HotelContentImage {
  const HotelContentImage({required this.imageUrl, required this.displayOrder});
  final String imageUrl;
  final int displayOrder;

  static HotelContentImage fromJson(Object? data) {
    final json = _asMap(data);
    return HotelContentImage(
      imageUrl: json['imageUrl']?.toString() ?? '',
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'imageUrl': imageUrl.trim(),
        'displayOrder': displayOrder,
      };
}

class HotelContentAmenity {
  const HotelContentAmenity({
    required this.code,
    required this.name,
    required this.type,
  });
  final String code;
  final String name;
  final String type;

  static HotelContentAmenity fromJson(Object? data) {
    final json = _asMap(data);
    return HotelContentAmenity(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code.trim(),
        'name': name.trim(),
        'type': type.trim(),
      };
}

class HotelCancellationPolicy {
  const HotelCancellationPolicy({
    required this.name,
    required this.freeCancellationHours,
    required this.refundPercentage,
    required this.description,
  });
  final String name;
  final int freeCancellationHours;
  final double refundPercentage;
  final String description;

  static HotelCancellationPolicy fromJson(Object? data) {
    final json = _asMap(data);
    return HotelCancellationPolicy(
      name: json['name']?.toString() ?? '',
      freeCancellationHours:
          (json['freeCancellationHours'] as num?)?.toInt() ?? 0,
      refundPercentage: (json['refundPercentage'] as num?)?.toDouble() ?? 0,
      description: json['description']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'freeCancellationHours': freeCancellationHours,
        'refundPercentage': refundPercentage,
        'description': description.trim().isEmpty ? null : description.trim(),
      };
}

class UpdateHotelContentRequest {
  const UpdateHotelContentRequest({
    required this.images,
    required this.amenities,
    required this.cancellationPolicy,
  });
  final List<HotelContentImage> images;
  final List<HotelContentAmenity> amenities;
  final HotelCancellationPolicy? cancellationPolicy;

  Map<String, dynamic> toJson() => {
        'images': images.map((item) => item.toJson()).toList(growable: false),
        'amenities':
            amenities.map((item) => item.toJson()).toList(growable: false),
        'cancellationPolicy': cancellationPolicy?.toJson(),
      };
}

class HotelStaffMember {
  const HotelStaffMember({
    required this.userAccountId,
    required this.assignmentId,
    required this.hotelId,
    required this.email,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
    required this.status,
    required this.isAssignmentActive,
    required this.assignedAtUtc,
  });

  final String userAccountId;
  final String assignmentId;
  final String hotelId;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final String role;
  final String status;
  final bool isAssignmentActive;
  final DateTime assignedAtUtc;

  static HotelStaffMember fromJson(Object? data) {
    final json = _asMap(data);
    return HotelStaffMember(
      userAccountId: json['userAccountId']?.toString() ?? '',
      assignmentId: json['assignmentId']?.toString() ?? '',
      hotelId: json['hotelId']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString(),
      role: json['role']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      isAssignmentActive: json['isAssignmentActive'] == true,
      assignedAtUtc:
          DateTime.tryParse(json['assignedAtUtc']?.toString() ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
    );
  }
}

class CreateStaffRequest {
  const CreateStaffRequest({
    required this.email,
    required this.password,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
  });

  final String email;
  final String password;
  final String fullName;
  final String phoneNumber;
  final String role;

  Map<String, dynamic> toJson() {
    return {
      'email': email.trim(),
      'password': password,
      'fullName': fullName.trim(),
      'phoneNumber': phoneNumber.trim(),
      'role': role,
    };
  }
}

class AttachStaffRequest {
  const AttachStaffRequest({required this.email, required this.role});

  final String email;
  final String role;

  Map<String, dynamic> toJson() {
    return {'email': email.trim(), 'role': role};
  }
}

class UpdateStaffAssignmentRequest {
  const UpdateStaffAssignmentRequest({this.role, this.isActive});

  final String? role;
  final bool? isActive;

  Map<String, dynamic> toJson() {
    return {
      if (role != null) 'role': role,
      if (isActive != null) 'isActive': isActive,
    };
  }
}

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

enum FrontDeskBookingListStatus {
  confirmed('Confirmed'),
  checkedIn('CheckedIn'),
  checkedOut('CheckedOut');

  const FrontDeskBookingListStatus(this.apiValue);
  final String apiValue;
}

class RoomInventoryItem {
  const RoomInventoryItem({
    required this.id,
    required this.hotelId,
    required this.roomTypeId,
    required this.roomNumber,
    required this.floor,
    required this.notes,
    required this.status,
  });

  final String id;
  final String hotelId;
  final String roomTypeId;
  final String roomNumber;
  final String? floor;
  final String? notes;
  final String status;

  bool get isAvailable => status == 'Available';

  static RoomInventoryItem fromJson(Object? data) {
    final json = _asMap(data);
    return RoomInventoryItem(
      id: json['id']?.toString() ?? '',
      hotelId: json['hotelId']?.toString() ?? '',
      roomTypeId: json['roomTypeId']?.toString() ?? '',
      roomNumber: json['roomNumber']?.toString() ?? '',
      floor: json['floor']?.toString(),
      notes: json['notes']?.toString(),
      status: json['status']?.toString() ?? '',
    );
  }
}

class RoomTypeInventoryItem {
  const RoomTypeInventoryItem({
    required this.id,
    required this.name,
    required this.adultCapacity,
    required this.childCapacity,
    required this.basePricePerNight,
    required this.description,
    required this.facilities,
    required this.status,
  });

  final String id;
  final String name;
  final int adultCapacity;
  final int childCapacity;
  final double basePricePerNight;
  final String? description;
  final String? facilities;
  final String status;

  int get totalCapacity => adultCapacity + childCapacity;

  String get displayName => name.trim().isEmpty ? shortCode : name.trim();

  String get shortCode {
    if (id.length <= 8) {
      return id;
    }

    return 'Room type ${id.substring(0, 8)}';
  }

  static RoomTypeInventoryItem fromJson(Object? data) {
    final json = _asMap(data);
    return RoomTypeInventoryItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      adultCapacity: (json['adultCapacity'] as num?)?.toInt() ?? 0,
      childCapacity: (json['childCapacity'] as num?)?.toInt() ?? 0,
      basePricePerNight: (json['basePricePerNight'] as num?)?.toDouble() ?? 0,
      description: json['description']?.toString(),
      facilities: json['facilities']?.toString(),
      status: json['status']?.toString() ?? '',
    );
  }
}

class CreateRoomTypeRequest {
  const CreateRoomTypeRequest({
    required this.name,
    required this.adultCapacity,
    required this.childCapacity,
    required this.basePricePerNight,
    required this.description,
    required this.facilities,
  });

  final String name;
  final int adultCapacity;
  final int childCapacity;
  final double basePricePerNight;
  final String description;
  final String facilities;

  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      'adultCapacity': adultCapacity,
      'childCapacity': childCapacity,
      'basePricePerNight': basePricePerNight,
      'description': description.trim().isEmpty ? null : description.trim(),
      'facilities': facilities.trim().isEmpty ? null : facilities.trim(),
    };
  }
}

class UpdateRoomTypeRequest extends CreateRoomTypeRequest {
  const UpdateRoomTypeRequest({
    required super.name,
    required super.adultCapacity,
    required super.childCapacity,
    required super.basePricePerNight,
    required super.description,
    required super.facilities,
  });
}

class CreatePhysicalRoomRequest {
  const CreatePhysicalRoomRequest({
    required this.roomTypeId,
    required this.roomNumber,
    required this.initialStatus,
    required this.floor,
    required this.notes,
  });

  final String roomTypeId;
  final String roomNumber;
  final String initialStatus;
  final String floor;
  final String notes;

  Map<String, dynamic> toJson() {
    return {
      'roomTypeId': roomTypeId,
      'roomNumber': roomNumber.trim(),
      'initialStatus': initialStatus,
      'floor': floor.trim().isEmpty ? null : floor.trim(),
      'notes': notes.trim().isEmpty ? null : notes.trim(),
    };
  }
}

class UpdatePhysicalRoomRequest {
  const UpdatePhysicalRoomRequest({
    required this.roomNumber,
    required this.status,
    required this.floor,
    required this.notes,
  });

  final String roomNumber;
  final String status;
  final String floor;
  final String notes;

  Map<String, dynamic> toJson() => {
        'roomNumber': roomNumber.trim(),
        'status': status,
        'floor': floor.trim().isEmpty ? null : floor.trim(),
        'notes': notes.trim().isEmpty ? null : notes.trim(),
      };
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

class FrontDeskBookingSummary {
  const FrontDeskBookingSummary({
    required this.bookingId,
    required this.bookingCode,
    required this.hotelId,
    required this.status,
    required this.paymentMode,
    required this.source,
    required this.checkInDate,
    required this.checkOutDate,
    required this.totalAmount,
    required this.guestFullName,
    required this.guestPhone,
    required this.roomTypeId,
    required this.roomTypeName,
    required this.roomQuantity,
    required this.nights,
    required this.assignedRooms,
    required this.guestStayRecordId,
    required this.invoiceId,
    required this.createdAtUtc,
  });

  final String bookingId;
  final String bookingCode;
  final String hotelId;
  final String status;
  final String paymentMode;
  final String source;
  final DateTime checkInDate;
  final DateTime checkOutDate;
  final double totalAmount;
  final String guestFullName;
  final String guestPhone;
  final String roomTypeId;
  final String roomTypeName;
  final int roomQuantity;
  final int nights;
  final List<AssignedRoomResult> assignedRooms;
  final String? guestStayRecordId;
  final String? invoiceId;
  final DateTime createdAtUtc;

  String get displayStayDates {
    return '${AppFormatters.displayDate(checkInDate)} - ${AppFormatters.displayDate(checkOutDate)}';
  }

  String get displayAssignedRooms {
    if (assignedRooms.isEmpty) {
      return 'Not assigned';
    }

    return assignedRooms.map((room) => room.roomNumber).join(', ');
  }

  static FrontDeskBookingSummary fromJson(Object? data) {
    final json = _asMap(data);
    final rooms = json['assignedRooms'];

    return FrontDeskBookingSummary(
      bookingId: json['bookingId']?.toString() ?? '',
      bookingCode: json['bookingCode']?.toString() ?? '',
      hotelId: json['hotelId']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      paymentMode: json['paymentMode']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      checkInDate: DateTime.tryParse(json['checkInDate']?.toString() ?? '') ??
          DateTime.now(),
      checkOutDate: DateTime.tryParse(json['checkOutDate']?.toString() ?? '') ??
          DateTime.now().add(const Duration(days: 1)),
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      guestFullName: json['guestFullName']?.toString() ?? '',
      guestPhone: json['guestPhone']?.toString() ?? '',
      roomTypeId: json['roomTypeId']?.toString() ?? '',
      roomTypeName: json['roomTypeName']?.toString() ?? '',
      roomQuantity: (json['roomQuantity'] as num?)?.toInt() ?? 0,
      nights: (json['nights'] as num?)?.toInt() ?? 0,
      assignedRooms: rooms is List
          ? rooms.map(AssignedRoomResult.fromJson).toList(growable: false)
          : const <AssignedRoomResult>[],
      guestStayRecordId: json['guestStayRecordId']?.toString(),
      invoiceId: json['invoiceId']?.toString(),
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc']?.toString() ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
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
    required this.bookingId,
    required this.assignedToUserAccountId,
    required this.taskType,
    required this.status,
    required this.roomStatus,
    required this.createdAtUtc,
  });

  final String id;
  final String physicalRoomId;
  final String roomNumber;
  final String? bookingId;
  final String? assignedToUserAccountId;
  final String taskType;
  final String status;
  final String roomStatus;
  final DateTime createdAtUtc;

  bool get isAssigned => assignedToUserAccountId != null;

  static HousekeepingTask fromJson(Object? data) {
    final json = _asMap(data);
    return HousekeepingTask(
      id: json['id']?.toString() ?? '',
      physicalRoomId: json['physicalRoomId']?.toString() ?? '',
      roomNumber: json['roomNumber']?.toString() ?? '',
      bookingId: json['bookingId']?.toString(),
      assignedToUserAccountId: json['assignedToUserAccountId']?.toString(),
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
    required this.assignedToUserAccountId,
    required this.severity,
    required this.status,
    required this.roomStatus,
    required this.createdAtUtc,
    required this.resolvedAtUtc,
    required this.resolutionNote,
  });

  final String id;
  final String physicalRoomId;
  final String roomNumber;
  final String description;
  final String? assignedToUserAccountId;
  final String severity;
  final String status;
  final String roomStatus;
  final DateTime createdAtUtc;
  final DateTime? resolvedAtUtc;
  final String? resolutionNote;

  String get displayCreatedAt => AppFormatters.displayDate(createdAtUtc);

  static MaintenanceRequestItem fromJson(Object? data) {
    final json = _asMap(data);
    return MaintenanceRequestItem(
      id: json['id']?.toString() ?? '',
      physicalRoomId: json['physicalRoomId']?.toString() ?? '',
      roomNumber: json['roomNumber']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      assignedToUserAccountId: json['assignedToUserAccountId']?.toString(),
      severity: json['severity']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      roomStatus: json['roomStatus']?.toString() ?? '',
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc']?.toString() ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
      resolvedAtUtc:
          DateTime.tryParse(json['resolvedAtUtc']?.toString() ?? '')?.toUtc(),
      resolutionNote: json['resolutionNote']?.toString(),
    );
  }
}

enum AvailabilityChangeAction {
  open('Open', 'Open room type'),
  close('Close', 'Close room type'),
  block('Block', 'Block room'),
  unblock('Unblock', 'Unblock room');

  const AvailabilityChangeAction(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

class AvailabilityCalendar {
  const AvailabilityCalendar({
    required this.hotelId,
    required this.startDate,
    required this.endDate,
    required this.roomTypes,
    required this.entries,
    required this.activeCommitments,
  });

  final String hotelId;
  final DateTime startDate;
  final DateTime endDate;
  final List<AvailabilityRoomType> roomTypes;
  final List<AvailabilityEntry> entries;
  final List<AvailabilityCommitment> activeCommitments;

  static AvailabilityCalendar fromJson(Object? data) {
    final json = _asMap(data);
    return AvailabilityCalendar(
      hotelId: json['hotelId']?.toString() ?? '',
      startDate: _parseDate(json['startDate']),
      endDate: _parseDate(json['endDate']),
      roomTypes: _asList(json['roomTypes'])
          .map(AvailabilityRoomType.fromJson)
          .toList(growable: false),
      entries: _asList(json['entries'])
          .map(AvailabilityEntry.fromJson)
          .toList(growable: false),
      activeCommitments: _asList(json['activeCommitments'])
          .map(AvailabilityCommitment.fromJson)
          .toList(growable: false),
    );
  }
}

class AvailabilityRoomType {
  const AvailabilityRoomType({
    required this.id,
    required this.name,
    required this.status,
    required this.physicalRooms,
  });

  final String id;
  final String name;
  final String status;
  final List<AvailabilityPhysicalRoom> physicalRooms;

  static AvailabilityRoomType fromJson(Object? data) {
    final json = _asMap(data);
    return AvailabilityRoomType(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      physicalRooms: _asList(json['physicalRooms'])
          .map(AvailabilityPhysicalRoom.fromJson)
          .toList(growable: false),
    );
  }
}

class AvailabilityPhysicalRoom {
  const AvailabilityPhysicalRoom({
    required this.id,
    required this.roomNumber,
    required this.status,
  });

  final String id;
  final String roomNumber;
  final String status;

  static AvailabilityPhysicalRoom fromJson(Object? data) {
    final json = _asMap(data);
    return AvailabilityPhysicalRoom(
      id: json['id']?.toString() ?? '',
      roomNumber: json['roomNumber']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }
}

class AvailabilityEntry {
  const AvailabilityEntry({
    required this.id,
    required this.roomTypeId,
    required this.physicalRoomId,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.reason,
  });

  final String id;
  final String roomTypeId;
  final String? physicalRoomId;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final String reason;

  static AvailabilityEntry fromJson(Object? data) {
    final json = _asMap(data);
    return AvailabilityEntry(
      id: json['id']?.toString() ?? '',
      roomTypeId: json['roomTypeId']?.toString() ?? '',
      physicalRoomId: json['physicalRoomId']?.toString(),
      startDate: _parseDate(json['startDate']),
      endDate: _parseDate(json['endDate']),
      status: json['status']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
    );
  }
}

class AvailabilityCommitment {
  const AvailabilityCommitment({
    required this.bookingId,
    required this.bookingCode,
    required this.roomTypeId,
    required this.checkInDate,
    required this.checkOutDate,
    required this.roomCount,
    required this.status,
    required this.assignedPhysicalRoomIds,
  });

  final String bookingId;
  final String bookingCode;
  final String roomTypeId;
  final DateTime checkInDate;
  final DateTime checkOutDate;
  final int roomCount;
  final String status;
  final List<String> assignedPhysicalRoomIds;

  static AvailabilityCommitment fromJson(Object? data) {
    final json = _asMap(data);
    return AvailabilityCommitment(
      bookingId: json['bookingId']?.toString() ?? '',
      bookingCode: json['bookingCode']?.toString() ?? '',
      roomTypeId: json['roomTypeId']?.toString() ?? '',
      checkInDate: _parseDate(json['checkInDate']),
      checkOutDate: _parseDate(json['checkOutDate']),
      roomCount: (json['roomCount'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? '',
      assignedPhysicalRoomIds: _asList(json['assignedPhysicalRoomIds'])
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }
}

DateTime _parseDate(Object? value) {
  return DateTime.tryParse(value?.toString() ?? '') ?? DateTime(2000);
}

List<Object?> _asList(Object? value) {
  return value is List ? value.cast<Object?>() : const <Object?>[];
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
