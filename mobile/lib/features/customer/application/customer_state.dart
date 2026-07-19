import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bookings/domain/booking_models.dart';
import '../../marketplace/domain/marketplace_models.dart';
import '../data/customer_account_api.dart';
import 'customer_account_providers.dart';

final customerStateProvider =
    StateNotifierProvider<CustomerStateController, CustomerState>((ref) {
  return CustomerStateController(ref.watch(customerAccountApiProvider));
});

class CustomerState {
  const CustomerState({
    this.savedHotels = const <SavedHotel>[],
    this.bookings = const <Booking>[],
    this.notifications = const <CustomerNotification>[],
    this.displayName = '',
    this.phoneNumber = '',
  });

  final List<SavedHotel> savedHotels;
  final List<Booking> bookings;
  final List<CustomerNotification> notifications;
  final String displayName;
  final String phoneNumber;

  CustomerState copyWith({
    List<SavedHotel>? savedHotels,
    List<Booking>? bookings,
    List<CustomerNotification>? notifications,
    String? displayName,
    String? phoneNumber,
  }) {
    return CustomerState(
      savedHotels: savedHotels ?? this.savedHotels,
      bookings: bookings ?? this.bookings,
      notifications: notifications ?? this.notifications,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}

class CustomerStateController extends StateNotifier<CustomerState> {
  CustomerStateController(this._api) : super(const CustomerState());

  final CustomerAccountApi _api;

  Future<void> loadEngagement() async {
    final results = await Future.wait<Object>([
      _api.getSavedHotels(),
      _api.getNotifications(),
    ]);
    state = state.copyWith(
      savedHotels: results[0] as List<SavedHotel>,
      notifications: results[1] as List<CustomerNotification>,
    );
  }

  bool isSaved(String hotelId) {
    return state.savedHotels.any((hotel) => hotel.id == hotelId);
  }

  Future<void> toggleSavedHotel(HotelSearchResult hotel) async {
    final exists = isSaved(hotel.id);
    if (exists) {
      state = state.copyWith(
        savedHotels:
            state.savedHotels.where((saved) => saved.id != hotel.id).toList(),
      );
      try {
        await _api.removeSavedHotel(hotel.id);
      } catch (_) {
        state = state.copyWith(
          savedHotels: [
            SavedHotel.fromSearchResult(hotel),
            ...state.savedHotels,
          ],
        );
        rethrow;
      }
      return;
    }

    state = state.copyWith(
      savedHotels: [
        SavedHotel.fromSearchResult(hotel),
        ...state.savedHotels,
      ],
    );
    try {
      final saved = await _api.saveHotel(hotel.id);
      state = state.copyWith(
        savedHotels: [
          saved,
          ...state.savedHotels.where((item) => item.id != hotel.id),
        ],
      );
    } catch (_) {
      state = state.copyWith(
        savedHotels:
            state.savedHotels.where((item) => item.id != hotel.id).toList(),
      );
      rethrow;
    }
  }

  Future<void> toggleSavedHotelDetail(HotelDetail hotel) async {
    final exists = isSaved(hotel.id);
    if (exists) {
      state = state.copyWith(
        savedHotels:
            state.savedHotels.where((saved) => saved.id != hotel.id).toList(),
      );
      try {
        await _api.removeSavedHotel(hotel.id);
      } catch (_) {
        state = state.copyWith(
          savedHotels: [
            SavedHotel.fromDetail(hotel),
            ...state.savedHotels,
          ],
        );
        rethrow;
      }
      return;
    }

    state = state.copyWith(
      savedHotels: [
        SavedHotel.fromDetail(hotel),
        ...state.savedHotels,
      ],
    );
    try {
      final saved = await _api.saveHotel(hotel.id);
      state = state.copyWith(
        savedHotels: [
          saved,
          ...state.savedHotels.where((item) => item.id != hotel.id),
        ],
      );
    } catch (_) {
      state = state.copyWith(
        savedHotels:
            state.savedHotels.where((item) => item.id != hotel.id).toList(),
      );
      rethrow;
    }
  }

  void addBooking(Booking booking) {
    final withoutDuplicate =
        state.bookings.where((item) => item.id != booking.id).toList();
    state = state.copyWith(
      bookings: [booking, ...withoutDuplicate],
    );
  }

  void markBookingDemoPaid(String bookingId) {
    state = state.copyWith(
      bookings: state.bookings.map((booking) {
        if (booking.id != bookingId) {
          return booking;
        }

        return booking.copyWith(status: 'Confirmed');
      }).toList(growable: false),
    );
  }

  void markBookingCancelled(String bookingId) {
    state = state.copyWith(
      bookings: state.bookings.map((booking) {
        return booking.id == bookingId
            ? booking.copyWith(status: 'Cancelled')
            : booking;
      }).toList(growable: false),
    );
  }

  Future<void> markNotificationsRead() async {
    final previous = state.notifications;
    state = state.copyWith(
      notifications: state.notifications
          .map((item) => item.copyWith(unread: false))
          .toList(growable: false),
    );
    try {
      await _api.markAllNotificationsRead();
    } catch (_) {
      state = state.copyWith(notifications: previous);
      rethrow;
    }
  }

  void updateProfile({
    required String displayName,
    required String phoneNumber,
  }) {
    state = state.copyWith(
      displayName: displayName.trim(),
      phoneNumber: phoneNumber.trim(),
    );
  }
}

class SavedHotel {
  const SavedHotel({
    required this.id,
    required this.name,
    required this.city,
    required this.addressLine,
    required this.minimumPricePerNight,
  });

  final String id;
  final String name;
  final String city;
  final String addressLine;
  final double minimumPricePerNight;

  factory SavedHotel.fromSearchResult(HotelSearchResult hotel) {
    return SavedHotel(
      id: hotel.id,
      name: hotel.name,
      city: hotel.city,
      addressLine: hotel.addressLine,
      minimumPricePerNight: hotel.minimumPricePerNight,
    );
  }

  factory SavedHotel.fromDetail(HotelDetail hotel) {
    final minimumPrice = hotel.availableRoomTypes.isEmpty
        ? 0.0
        : hotel.availableRoomTypes
            .map((roomType) => roomType.basePricePerNight)
            .reduce((left, right) => left < right ? left : right);

    return SavedHotel(
      id: hotel.id,
      name: hotel.name,
      city: hotel.city,
      addressLine: hotel.addressLine,
      minimumPricePerNight: minimumPrice,
    );
  }

  factory SavedHotel.fromJson(Object? data) {
    final json = _asMap(data);
    return SavedHotel(
      id: json['hotelId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      addressLine: json['addressLine']?.toString() ?? '',
      minimumPricePerNight:
          (json['minimumPricePerNight'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CustomerNotification {
  const CustomerNotification({
    required this.title,
    required this.body,
    required this.createdLabel,
    required this.unread,
  });

  final String title;
  final String body;
  final String createdLabel;
  final bool unread;

  CustomerNotification copyWith({bool? unread}) {
    return CustomerNotification(
      title: title,
      body: body,
      createdLabel: createdLabel,
      unread: unread ?? this.unread,
    );
  }

  factory CustomerNotification.fromJson(Object? data) {
    final json = _asMap(data);
    final createdAt =
        DateTime.tryParse(json['createdAtUtc']?.toString() ?? '')?.toLocal();
    final createdLabel = createdAt == null
        ? ''
        : '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    return CustomerNotification(
      title: _notificationTitle(json['eventType']?.toString() ?? ''),
      body: json['message']?.toString() ?? '',
      createdLabel: createdLabel,
      unread: json['readAtUtc'] == null,
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

String _notificationTitle(String eventType) {
  return eventType
      .replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (_) => ' ')
      .trim();
}
