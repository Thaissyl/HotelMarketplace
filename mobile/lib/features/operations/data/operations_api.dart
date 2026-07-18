import '../../../core/network/api_client.dart';
import '../../../core/network/auth_header_interceptor.dart';
import '../../../shared/utils/app_formatters.dart';
import '../domain/operations_models.dart';

class OperationsApi {
  OperationsApi(this._apiClient);

  final ApiClient _apiClient;

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
      '/api/owner/hotels/$hotelId',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      decoder: WorkingHotel.fromJson,
    );
  }

  Future<WorkingHotel> updateOwnerHotel({
    required String hotelId,
    required UpdateHotelProfileRequest request,
  }) {
    return _apiClient.put<WorkingHotel>(
      '/api/owner/hotels/$hotelId',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      data: request.toJson(),
      decoder: WorkingHotel.fromJson,
    );
  }

  Future<RoomTypeInventoryItem> createRoomType({
    required String hotelId,
    required CreateRoomTypeRequest request,
  }) {
    return _apiClient.post<RoomTypeInventoryItem>(
      '/api/owner/hotels/$hotelId/room-types',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      data: request.toJson(),
      decoder: RoomTypeInventoryItem.fromJson,
    );
  }

  Future<RoomInventoryItem> createPhysicalRoom({
    required String hotelId,
    required CreatePhysicalRoomRequest request,
  }) {
    return _apiClient.post<RoomInventoryItem>(
      '/api/owner/hotels/$hotelId/physical-rooms',
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
      '/api/owner/hotels/$hotelId/staff',
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
    required String identityDocumentNumber,
  }) {
    return _apiClient.post<FrontDeskBookingResult>(
      '/api/hotels/$hotelId/front-desk/bookings/$bookingId/check-in',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      data: {
        'physicalRoomIds': physicalRoomIds,
        'guestFullName': guestFullName.trim(),
        'identityDocumentNumber': identityDocumentNumber.trim().isEmpty
            ? null
            : identityDocumentNumber.trim(),
      },
      decoder: FrontDeskBookingResult.fromJson,
    );
  }

  Future<FrontDeskBookingResult> checkOut({
    required String hotelId,
    required String bookingId,
    required bool confirmPayAtPropertyCollection,
    required double cashCollectedAmount,
  }) {
    return _apiClient.post<FrontDeskBookingResult>(
      '/api/hotels/$hotelId/front-desk/bookings/$bookingId/check-out',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      data: {
        'confirmPayAtPropertyCollection': confirmPayAtPropertyCollection,
        'cashCollectedAmount': cashCollectedAmount,
      },
      decoder: FrontDeskBookingResult.fromJson,
    );
  }

  Future<FrontDeskBookingResult> createWalkInBooking({
    required String hotelId,
    required String roomTypeId,
    required List<String> physicalRoomIds,
    required DateTime checkInDate,
    required DateTime checkOutDate,
    required int guestCount,
    required String guestFullName,
    required String guestPhone,
    required String identityDocumentNumber,
    required double cashCollectedAmount,
  }) {
    return _apiClient.post<FrontDeskBookingResult>(
      '/api/hotels/$hotelId/front-desk/walk-in-bookings',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      data: {
        'roomTypeId': roomTypeId,
        'physicalRoomIds': physicalRoomIds,
        'checkInDate': AppFormatters.apiDate(checkInDate),
        'checkOutDate': AppFormatters.apiDate(checkOutDate),
        'guestCount': guestCount,
        'guestFullName': guestFullName.trim(),
        'guestPhone': guestPhone.trim(),
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
  }) {
    return _apiClient.patch<MaintenanceRequestItem>(
      '/api/hotels/$hotelId/maintenance/requests/$requestId/status',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      data: {'status': status.apiValue},
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
