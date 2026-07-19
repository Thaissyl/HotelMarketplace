import '../../../core/network/api_client.dart';
import '../../../core/network/auth_header_interceptor.dart';
import '../../../shared/utils/app_formatters.dart';
import '../domain/operations_models.dart';

class OperationsApi {
  OperationsApi(this._apiClient);

  final ApiClient _apiClient;

  Future<WorkingHotel> registerHotel(RegisterHotelRequest request) {
    return _apiClient.post<WorkingHotel>(
      '/api/owner/hotels',
      data: request.toJson(),
      decoder: WorkingHotel.fromJson,
    );
  }

  Future<List<WorkingHotel>> getWorkingHotels(List<String> hotelIds) async {
    try {
      return await _apiClient.get<List<WorkingHotel>>(
        '/api/operations/hotels',
        decoder: (data) {
          if (data is! List) {
            return hotelIds.map(WorkingHotel.fallback).toList(growable: false);
          }

          return data.map(WorkingHotel.fromJson).toList(growable: false);
        },
      );
    } catch (_) {
      return hotelIds.map(WorkingHotel.fallback).toList(growable: false);
    }
  }

  Future<AvailabilityCalendar> getAvailabilityCalendar({
    required String hotelId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return _apiClient.get<AvailabilityCalendar>(
      '/api/hotels/$hotelId/availability',
      queryParameters: {
        'startDate': AppFormatters.apiDate(startDate),
        'endDate': AppFormatters.apiDate(endDate),
      },
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      decoder: AvailabilityCalendar.fromJson,
    );
  }

  Future<AvailabilityCalendar> changeAvailability({
    required String hotelId,
    required String roomTypeId,
    required String? physicalRoomId,
    required DateTime startDate,
    required DateTime endDate,
    required AvailabilityChangeAction action,
    required String? reason,
  }) {
    return _apiClient.post<AvailabilityCalendar>(
      '/api/hotels/$hotelId/availability/changes',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      data: {
        'roomTypeId': roomTypeId,
        'physicalRoomId': physicalRoomId,
        'startDate': AppFormatters.apiDate(startDate),
        'endDate': AppFormatters.apiDate(endDate),
        'action': action.apiValue,
        'reason':
            reason == null || reason.trim().isEmpty ? null : reason.trim(),
      },
      decoder: AvailabilityCalendar.fromJson,
    );
  }

  Future<List<RoomInventoryItem>> getPhysicalRooms({
    required String hotelId,
    String? roomTypeId,
  }) {
    return _apiClient.get<List<RoomInventoryItem>>(
      '/api/hotels/$hotelId/front-desk/physical-rooms',
      queryParameters: {
        if (roomTypeId != null && roomTypeId.isNotEmpty)
          'roomTypeId': roomTypeId,
      },
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      decoder: (data) {
        if (data is! List) {
          return const <RoomInventoryItem>[];
        }

        return data.map(RoomInventoryItem.fromJson).toList(growable: false);
      },
    );
  }

  Future<List<FrontDeskBookingSummary>> getFrontDeskBookings({
    required String hotelId,
    FrontDeskBookingListStatus? status,
  }) {
    return _apiClient.get<List<FrontDeskBookingSummary>>(
      '/api/hotels/$hotelId/front-desk/bookings',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      queryParameters: {
        if (status != null) 'status': status.apiValue,
      },
      decoder: (data) {
        if (data is! List) {
          return const <FrontDeskBookingSummary>[];
        }

        return data
            .map(FrontDeskBookingSummary.fromJson)
            .toList(growable: false);
      },
    );
  }

  Future<List<RoomTypeInventoryItem>> getRoomTypes(String hotelId) {
    return _apiClient.get<List<RoomTypeInventoryItem>>(
      '/api/operations/hotels/$hotelId/room-types',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      decoder: (data) {
        if (data is! List) {
          return const <RoomTypeInventoryItem>[];
        }

        return data.map(RoomTypeInventoryItem.fromJson).toList(growable: false);
      },
    );
  }

  Future<WorkingHotel> getOwnerHotel(String hotelId) {
    return _apiClient.get<WorkingHotel>(
      '/api/operations/hotels/$hotelId',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      decoder: WorkingHotel.fromJson,
    );
  }

  Future<WorkingHotel> updateOwnerHotel({
    required String hotelId,
    required UpdateHotelProfileRequest request,
  }) {
    return _apiClient.put<WorkingHotel>(
      '/api/operations/hotels/$hotelId',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      data: request.toJson(),
      decoder: WorkingHotel.fromJson,
    );
  }

  Future<HotelContent> getHotelContent(String hotelId) {
    return _apiClient.get<HotelContent>(
      '/api/operations/hotels/$hotelId/content',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      decoder: HotelContent.fromJson,
    );
  }

  Future<HotelContent> updateHotelContent({
    required String hotelId,
    required UpdateHotelContentRequest request,
  }) {
    return _apiClient.put<HotelContent>(
      '/api/operations/hotels/$hotelId/content',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      data: request.toJson(),
      decoder: HotelContent.fromJson,
    );
  }

  Future<RoomTypeInventoryItem> createRoomType({
    required String hotelId,
    required CreateRoomTypeRequest request,
  }) {
    return _apiClient.post<RoomTypeInventoryItem>(
      '/api/operations/hotels/$hotelId/room-types',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      data: request.toJson(),
      decoder: RoomTypeInventoryItem.fromJson,
    );
  }

  Future<RoomTypeInventoryItem> updateRoomType({
    required String hotelId,
    required String roomTypeId,
    required UpdateRoomTypeRequest request,
  }) {
    return _apiClient.put<RoomTypeInventoryItem>(
      '/api/operations/hotels/$hotelId/room-types/$roomTypeId',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      data: request.toJson(),
      decoder: RoomTypeInventoryItem.fromJson,
    );
  }

  Future<void> deactivateRoomType({
    required String hotelId,
    required String roomTypeId,
  }) {
    return _apiClient.delete(
      '/api/operations/hotels/$hotelId/room-types/$roomTypeId',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
    );
  }

  Future<RoomInventoryItem> createPhysicalRoom({
    required String hotelId,
    required CreatePhysicalRoomRequest request,
  }) {
    return _apiClient.post<RoomInventoryItem>(
      '/api/operations/hotels/$hotelId/physical-rooms',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      data: request.toJson(),
      decoder: RoomInventoryItem.fromJson,
    );
  }

  Future<RoomInventoryItem> updatePhysicalRoom({
    required String hotelId,
    required String physicalRoomId,
    required UpdatePhysicalRoomRequest request,
  }) {
    return _apiClient.put<RoomInventoryItem>(
      '/api/operations/hotels/$hotelId/physical-rooms/$physicalRoomId',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      data: request.toJson(),
      decoder: RoomInventoryItem.fromJson,
    );
  }

  Future<List<HotelStaffMember>> getStaff(String hotelId) {
    return _apiClient.get<List<HotelStaffMember>>(
      '/api/operations/hotels/$hotelId/staff',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      decoder: (data) {
        if (data is! List) {
          return const <HotelStaffMember>[];
        }

        return data.map(HotelStaffMember.fromJson).toList(growable: false);
      },
    );
  }

  Future<HotelStaffMember> createStaff({
    required String hotelId,
    required CreateStaffRequest request,
  }) {
    return _apiClient.post<HotelStaffMember>(
      '/api/operations/hotels/$hotelId/staff',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      data: request.toJson(),
      decoder: HotelStaffMember.fromJson,
    );
  }

  Future<HotelStaffMember> attachStaff({
    required String hotelId,
    required AttachStaffRequest request,
  }) {
    return _apiClient.post<HotelStaffMember>(
      '/api/operations/hotels/$hotelId/staff/attachments',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      data: request.toJson(),
      decoder: HotelStaffMember.fromJson,
    );
  }

  Future<HotelStaffMember> updateStaffAssignment({
    required String hotelId,
    required String assignmentId,
    required UpdateStaffAssignmentRequest request,
  }) {
    return _apiClient.patch<HotelStaffMember>(
      '/api/operations/hotels/$hotelId/staff/$assignmentId',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      data: request.toJson(),
      decoder: HotelStaffMember.fromJson,
    );
  }

  Future<FrontDeskBookingResult> checkIn({
    required String hotelId,
    required String bookingId,
    required List<String> physicalRoomIds,
    required String guestFullName,
    required String identityDocumentType,
    required String identityDocumentNumber,
    String? identityIssuingCountry,
    DateTime? identityExpiryDate,
  }) {
    return _apiClient.post<FrontDeskBookingResult>(
      '/api/hotels/$hotelId/front-desk/bookings/$bookingId/check-in',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      data: {
        'physicalRoomIds': physicalRoomIds,
        'guestFullName': guestFullName.trim(),
        'identityDocumentType': identityDocumentType.trim(),
        'identityDocumentNumber': identityDocumentNumber.trim(),
        'identityIssuingCountry': identityIssuingCountry?.trim().isEmpty == true
            ? null
            : identityIssuingCountry?.trim().toUpperCase(),
        'identityExpiryDate': identityExpiryDate == null
            ? null
            : AppFormatters.apiDate(identityExpiryDate),
      },
      decoder: FrontDeskBookingResult.fromJson,
    );
  }

  Future<FrontDeskBookingResult> assignBookingRooms({
    required String hotelId,
    required String bookingId,
    required List<String> physicalRoomIds,
  }) {
    return _apiClient.put<FrontDeskBookingResult>(
      '/api/hotels/$hotelId/front-desk/bookings/$bookingId/room-assignments',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      data: {'physicalRoomIds': physicalRoomIds},
      decoder: FrontDeskBookingResult.fromJson,
    );
  }

  Future<FrontDeskBookingResult> checkOut({
    required String hotelId,
    required String bookingId,
    required bool confirmPayAtPropertyCollection,
    required double cashCollectedAmount,
    required String collectionMethod,
    required String collectionReference,
    required String collectionNote,
  }) {
    return _apiClient.post<FrontDeskBookingResult>(
      '/api/hotels/$hotelId/front-desk/bookings/$bookingId/check-out',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      data: {
        'confirmPayAtPropertyCollection': confirmPayAtPropertyCollection,
        'cashCollectedAmount': cashCollectedAmount,
        'collectionMethod': collectionMethod,
        'collectionReference': collectionReference.trim().isEmpty
            ? null
            : collectionReference.trim(),
        'collectionNote':
            collectionNote.trim().isEmpty ? null : collectionNote.trim(),
      },
      decoder: FrontDeskBookingResult.fromJson,
    );
  }

  Future<FrontDeskBookingResult> markBookingNoShow({
    required String hotelId,
    required String bookingId,
    required String reason,
  }) {
    return _apiClient.post<FrontDeskBookingResult>(
      '/api/hotels/$hotelId/front-desk/bookings/$bookingId/no-show',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      data: {'reason': reason.trim()},
      decoder: FrontDeskBookingResult.fromJson,
    );
  }

  Future<FrontDeskBookingResult> createWalkInBooking({
    required String hotelId,
    required String roomTypeId,
    required int roomCount,
    required List<String> physicalRoomIds,
    required DateTime checkInDate,
    required DateTime checkOutDate,
    required int guestCount,
    required String guestFullName,
    required String guestPhone,
    required String identityDocumentType,
    required String identityDocumentNumber,
    required double cashCollectedAmount,
  }) {
    return _apiClient.post<FrontDeskBookingResult>(
      '/api/hotels/$hotelId/front-desk/walk-in-bookings',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      data: {
        'roomTypeId': roomTypeId,
        'roomCount': roomCount,
        'physicalRoomIds': physicalRoomIds,
        'checkInDate': AppFormatters.apiDate(checkInDate),
        'checkOutDate': AppFormatters.apiDate(checkOutDate),
        'guestCount': guestCount,
        'guestFullName': guestFullName.trim(),
        'guestPhone': guestPhone.trim(),
        'identityDocumentType': identityDocumentType.trim().isEmpty
            ? null
            : identityDocumentType.trim(),
        'identityDocumentNumber': identityDocumentNumber.trim().isEmpty
            ? null
            : identityDocumentNumber.trim(),
        'cashCollectedAmount': cashCollectedAmount,
      },
      decoder: FrontDeskBookingResult.fromJson,
    );
  }

  Future<List<HousekeepingTask>> getHousekeepingTasks({
    required String hotelId,
    HousekeepingTaskStatus? status,
  }) {
    return _apiClient.get<List<HousekeepingTask>>(
      '/api/hotels/$hotelId/housekeeping/tasks',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      queryParameters: {
        if (status != null) 'status': status.apiValue,
      },
      decoder: (data) {
        if (data is! List) {
          return const <HousekeepingTask>[];
        }

        return data.map(HousekeepingTask.fromJson).toList(growable: false);
      },
    );
  }

  Future<HousekeepingTask> updateHousekeepingTaskStatus({
    required String hotelId,
    required String taskId,
    required HousekeepingTaskStatus status,
  }) {
    return _apiClient.patch<HousekeepingTask>(
      '/api/hotels/$hotelId/housekeeping/tasks/$taskId/status',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      data: {'status': status.apiValue},
      decoder: HousekeepingTask.fromJson,
    );
  }

  Future<HousekeepingTask> assignHousekeepingTask({
    required String hotelId,
    required String taskId,
    required String assignedToUserAccountId,
  }) {
    return _apiClient.patch<HousekeepingTask>(
      '/api/hotels/$hotelId/housekeeping/tasks/$taskId/assignee',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      data: {'assignedToUserAccountId': assignedToUserAccountId},
      decoder: HousekeepingTask.fromJson,
    );
  }

  Future<HousekeepingTask> completeHousekeepingInspection({
    required String hotelId,
    required String taskId,
  }) {
    return _apiClient.post<HousekeepingTask>(
      '/api/hotels/$hotelId/housekeeping/tasks/$taskId/inspection',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      data: const <String, dynamic>{},
      decoder: HousekeepingTask.fromJson,
    );
  }

  Future<List<MaintenanceRequestItem>> getMaintenanceRequests({
    required String hotelId,
    MaintenanceStatus? status,
  }) {
    return _apiClient.get<List<MaintenanceRequestItem>>(
      '/api/hotels/$hotelId/maintenance/requests',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      queryParameters: {
        if (status != null) 'status': status.apiValue,
      },
      decoder: (data) {
        if (data is! List) {
          return const <MaintenanceRequestItem>[];
        }

        return data
            .map(MaintenanceRequestItem.fromJson)
            .toList(growable: false);
      },
    );
  }

  Future<List<RoomInventoryItem>> getMaintenanceRooms({
    required String hotelId,
  }) {
    return _apiClient.get<List<RoomInventoryItem>>(
      '/api/hotels/$hotelId/maintenance/rooms',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      decoder: (data) {
        if (data is! List) {
          return const <RoomInventoryItem>[];
        }

        return data.map(RoomInventoryItem.fromJson).toList(growable: false);
      },
    );
  }

  Future<MaintenanceRequestItem> reportMaintenanceIssue({
    required String hotelId,
    required String physicalRoomId,
    required String description,
    required MaintenanceSeverity severity,
    required String targetRoomStatus,
  }) {
    return _apiClient.post<MaintenanceRequestItem>(
      '/api/hotels/$hotelId/maintenance/requests',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      data: {
        'physicalRoomId': physicalRoomId,
        'description': description.trim(),
        'severity': severity.apiValue,
        'targetRoomStatus': targetRoomStatus,
      },
      decoder: MaintenanceRequestItem.fromJson,
    );
  }

  Future<MaintenanceRequestItem> updateMaintenanceRequestStatus({
    required String hotelId,
    required String requestId,
    required MaintenanceStatus status,
    String? resolutionNote,
  }) {
    return _apiClient.patch<MaintenanceRequestItem>(
      '/api/hotels/$hotelId/maintenance/requests/$requestId/status',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      data: {
        'status': status.apiValue,
        'resolutionNote': resolutionNote?.trim().isEmpty == true
            ? null
            : resolutionNote?.trim(),
      },
      decoder: MaintenanceRequestItem.fromJson,
    );
  }

  Future<MaintenanceRequestItem> assignMaintenanceRequest({
    required String hotelId,
    required String requestId,
    required String assignedToUserAccountId,
  }) {
    return _apiClient.patch<MaintenanceRequestItem>(
      '/api/hotels/$hotelId/maintenance/requests/$requestId/assignee',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      data: {'assignedToUserAccountId': assignedToUserAccountId},
      decoder: MaintenanceRequestItem.fromJson,
    );
  }
}
