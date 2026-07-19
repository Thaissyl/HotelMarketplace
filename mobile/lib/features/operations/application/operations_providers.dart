import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/core_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/operations_api.dart';
import '../domain/operations_models.dart';

final operationsApiProvider = Provider<OperationsApi>((ref) {
  return OperationsApi(ref.watch(apiClientProvider));
});

final availabilityCalendarProvider = FutureProvider.autoDispose
    .family<AvailabilityCalendar, AvailabilityCalendarRequest>((ref, request) {
  return ref.watch(operationsApiProvider).getAvailabilityCalendar(
        hotelId: request.hotelId,
        startDate: request.startDate,
        endDate: request.endDate,
      );
});

final workingHotelsProvider = FutureProvider.autoDispose<List<WorkingHotel>>((
  ref,
) {
  final hotelIds =
      ref.watch(authControllerProvider).userSession?.hotelIds ?? const [];
  return ref.watch(operationsApiProvider).getWorkingHotels(hotelIds);
});

final physicalRoomsProvider = FutureProvider.autoDispose
    .family<List<RoomInventoryItem>, PhysicalRoomsRequest>((ref, request) {
  return ref.watch(operationsApiProvider).getPhysicalRooms(
        hotelId: request.hotelId,
        roomTypeId: request.roomTypeId,
      );
});

final frontDeskBookingsProvider = FutureProvider.autoDispose
    .family<List<FrontDeskBookingSummary>, FrontDeskBookingsRequest>(
  (ref, request) {
    return ref.watch(operationsApiProvider).getFrontDeskBookings(
          hotelId: request.hotelId,
          status: request.status,
        );
  },
);

final roomTypesProvider =
    FutureProvider.autoDispose.family<List<RoomTypeInventoryItem>, String>(
  (ref, hotelId) {
    return ref.watch(operationsApiProvider).getRoomTypes(hotelId);
  },
);

final ownerHotelProvider =
    FutureProvider.autoDispose.family<WorkingHotel, String>((ref, hotelId) {
  return ref.watch(operationsApiProvider).getOwnerHotel(hotelId);
});

final hotelStaffProvider =
    FutureProvider.autoDispose.family<List<HotelStaffMember>, String>(
  (ref, hotelId) {
    return ref.watch(operationsApiProvider).getStaff(hotelId);
  },
);

final hotelContentProvider =
    FutureProvider.autoDispose.family<HotelContent, String>((ref, hotelId) {
  return ref.watch(operationsApiProvider).getHotelContent(hotelId);
});

final housekeepingTasksProvider = FutureProvider.autoDispose
    .family<List<HousekeepingTask>, HousekeepingTasksRequest>((ref, request) {
  return ref.watch(operationsApiProvider).getHousekeepingTasks(
        hotelId: request.hotelId,
        status: request.status,
      );
});

final maintenanceRequestsProvider = FutureProvider.autoDispose
    .family<List<MaintenanceRequestItem>, MaintenanceRequestsRequest>(
  (ref, request) {
    return ref.watch(operationsApiProvider).getMaintenanceRequests(
          hotelId: request.hotelId,
          status: request.status,
        );
  },
);

final maintenanceRoomsProvider =
    FutureProvider.autoDispose.family<List<RoomInventoryItem>, String>(
  (ref, hotelId) {
    return ref.watch(operationsApiProvider).getMaintenanceRooms(
          hotelId: hotelId,
        );
  },
);

class PhysicalRoomsRequest {
  const PhysicalRoomsRequest({
    required this.hotelId,
    this.roomTypeId,
  });

  final String hotelId;
  final String? roomTypeId;

  @override
  bool operator ==(Object other) {
    return other is PhysicalRoomsRequest &&
        other.hotelId == hotelId &&
        other.roomTypeId == roomTypeId;
  }

  @override
  int get hashCode => Object.hash(hotelId, roomTypeId);
}

class AvailabilityCalendarRequest {
  const AvailabilityCalendarRequest({
    required this.hotelId,
    required this.startDate,
    required this.endDate,
  });

  final String hotelId;
  final DateTime startDate;
  final DateTime endDate;

  @override
  bool operator ==(Object other) {
    return other is AvailabilityCalendarRequest &&
        other.hotelId == hotelId &&
        other.startDate == startDate &&
        other.endDate == endDate;
  }

  @override
  int get hashCode => Object.hash(hotelId, startDate, endDate);
}

class FrontDeskBookingsRequest {
  const FrontDeskBookingsRequest({
    required this.hotelId,
    this.status,
  });

  final String hotelId;
  final FrontDeskBookingListStatus? status;

  @override
  bool operator ==(Object other) {
    return other is FrontDeskBookingsRequest &&
        other.hotelId == hotelId &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(hotelId, status);
}

class HousekeepingTasksRequest {
  const HousekeepingTasksRequest({
    required this.hotelId,
    this.status,
  });

  final String hotelId;
  final HousekeepingTaskStatus? status;

  @override
  bool operator ==(Object other) {
    return other is HousekeepingTasksRequest &&
        other.hotelId == hotelId &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(hotelId, status);
}

class MaintenanceRequestsRequest {
  const MaintenanceRequestsRequest({
    required this.hotelId,
    this.status,
  });

  final String hotelId;
  final MaintenanceStatus? status;

  @override
  bool operator ==(Object other) {
    return other is MaintenanceRequestsRequest &&
        other.hotelId == hotelId &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(hotelId, status);
}
