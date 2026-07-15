import '../../../core/network/api_client.dart';
import '../../../core/network/auth_header_interceptor.dart';
import '../../../shared/utils/app_formatters.dart';
import '../domain/operations_models.dart';

class OperationsApi {
  OperationsApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<RoomInventoryItem>> getPhysicalRooms({
    required String hotelId,
    String? roomTypeId,
  }) {
    return _apiClient.get<List<RoomInventoryItem>>(
      '/api/owner/hotels/$hotelId/physical-rooms',
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

  Future<List<RoomTypeInventoryItem>> getRoomTypes(String hotelId) {
    return _apiClient.get<List<RoomTypeInventoryItem>>(
      '/api/owner/hotels/$hotelId/room-types',
      options: AuthHeaderInterceptor.hotelScopedOptions(),
      decoder: (data) {
        if (data is! List) {
          return const <RoomTypeInventoryItem>[];
        }

        return data.map(RoomTypeInventoryItem.fromJson).toList(growable: false);
      },
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
}
