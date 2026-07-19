import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bookings/domain/booking_models.dart';
import '../../marketplace/domain/marketplace_models.dart';

final customerStateProvider =
    StateNotifierProvider<CustomerStateController, CustomerState>((ref) {
  return CustomerStateController();
});

class CustomerState {
  const CustomerState({
    this.savedHotels = const <SavedHotel>[],
    this.bookings = const <Booking>[],
    this.notifications = const <CustomerNotification>[
      CustomerNotification(
        title: 'Welcome to Hotel Marketplace',
        body: 'Search hotels, save favorites, and manage upcoming stays here.',
        createdLabel: 'Today',
        unread: true,
      ),
    ],
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
  CustomerStateController() : super(const CustomerState());

  bool isSaved(String hotelId) {
    return state.savedHotels.any((hotel) => hotel.id == hotelId);
  }

  void toggleSavedHotel(HotelSearchResult hotel) {
    final exists = isSaved(hotel.id);
    if (exists) {
      state = state.copyWith(
        savedHotels:
            state.savedHotels.where((saved) => saved.id != hotel.id).toList(),
      );
      return;
    }

    state = state.copyWith(
      savedHotels: [
        SavedHotel.fromSearchResult(hotel),
        ...state.savedHotels,
      ],
      notifications: [
        CustomerNotification(
          title: 'Hotel saved',
          body: '${hotel.name} was added to your saved hotels.',
          createdLabel: 'Now',
          unread: true,
        ),
        ...state.notifications,
      ],
    );
  }

  void toggleSavedHotelDetail(HotelDetail hotel) {
    final exists = isSaved(hotel.id);
    if (exists) {
      state = state.copyWith(
        savedHotels:
            state.savedHotels.where((saved) => saved.id != hotel.id).toList(),
      );
      return;
    }

    state = state.copyWith(
      savedHotels: [
        SavedHotel.fromDetail(hotel),
        ...state.savedHotels,
      ],
      notifications: [
        CustomerNotification(
          title: 'Hotel saved',
          body: '${hotel.name} was added to your saved hotels.',
          createdLabel: 'Now',
          unread: true,
        ),
        ...state.notifications,
      ],
    );
  }

  void addBooking(Booking booking) {
    final withoutDuplicate =
        state.bookings.where((item) => item.id != booking.id).toList();
    state = state.copyWith(
      bookings: [booking, ...withoutDuplicate],
      notifications: [
        CustomerNotification(
          title: 'Reservation created',
          body: 'Booking ${booking.bookingCode} is being held for payment.',
          createdLabel: 'Now',
          unread: true,
        ),
        ...state.notifications,
      ],
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
      notifications: [
        const CustomerNotification(
          title: 'Demo payment completed',
          body: 'Your booking has been confirmed in demo mode.',
          createdLabel: 'Now',
          unread: true,
        ),
        ...state.notifications,
      ],
    );
  }

  void markBookingCancelled(String bookingId) {
    state = state.copyWith(
      bookings: state.bookings.map((booking) {
        return booking.id == bookingId
            ? booking.copyWith(status: 'Cancelled')
            : booking;
      }).toList(growable: false),
      notifications: [
        const CustomerNotification(
          title: 'Booking cancelled',
          body: 'Your cancellation was recorded. Check Trips for details.',
          createdLabel: 'Now',
          unread: true,
        ),
        ...state.notifications,
      ],
    );
  }

  void markNotificationsRead() {
    state = state.copyWith(
      notifications: state.notifications
          .map((item) => item.copyWith(unread: false))
          .toList(growable: false),
    );
  }

  void updateProfile({
    required String displayName,
    required String phoneNumber,
  }) {
    state = state.copyWith(
      displayName: displayName.trim(),
      phoneNumber: phoneNumber.trim(),
      notifications: [
        const CustomerNotification(
          title: 'Profile updated',
          body: 'Your local customer profile information was updated.',
          createdLabel: 'Now',
          unread: true,
        ),
        ...state.notifications,
      ],
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
}
