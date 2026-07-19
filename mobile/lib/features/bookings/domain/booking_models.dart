import '../../../shared/utils/app_formatters.dart';

class CreateBookingRequest {
  const CreateBookingRequest({
    required this.hotelId,
    required this.roomTypeId,
    required this.checkInDate,
    required this.checkOutDate,
    required this.roomCount,
    required this.guestCount,
    required this.guestFullName,
    required this.guestPhone,
  });

  final String hotelId;
  final String roomTypeId;
  final DateTime checkInDate;
  final DateTime checkOutDate;
  final int roomCount;
  final int guestCount;
  final String guestFullName;
  final String guestPhone;

  Map<String, dynamic> toJson() {
    return {
      'hotelId': hotelId,
      'roomTypeId': roomTypeId,
      'checkInDate': AppFormatters.apiDate(checkInDate),
      'checkOutDate': AppFormatters.apiDate(checkOutDate),
      'roomCount': roomCount,
      'guestCount': guestCount,
      'guestFullName': guestFullName.trim(),
      'guestPhone': guestPhone.trim(),
    };
  }
}

class Booking {
  const Booking({
    required this.id,
    required this.bookingCode,
    required this.hotelId,
    required this.roomTypeId,
    required this.checkInDate,
    required this.checkOutDate,
    required this.roomCount,
    required this.guestCount,
    required this.nights,
    required this.unitPricePerNight,
    required this.totalAmount,
    required this.status,
    required this.createdAtUtc,
    required this.paymentExpiresAtUtc,
    required this.guestFullName,
    required this.guestPhone,
  });

  final String id;
  final String bookingCode;
  final String hotelId;
  final String roomTypeId;
  final DateTime checkInDate;
  final DateTime checkOutDate;
  final int roomCount;
  final int guestCount;
  final int nights;
  final double unitPricePerNight;
  final double totalAmount;
  final String status;
  final DateTime createdAtUtc;
  final DateTime? paymentExpiresAtUtc;
  final String guestFullName;
  final String guestPhone;

  bool get isPendingPayment => status == 'PendingPayment';

  Booking copyWith({
    String? status,
    DateTime? paymentExpiresAtUtc,
  }) {
    return Booking(
      id: id,
      bookingCode: bookingCode,
      hotelId: hotelId,
      roomTypeId: roomTypeId,
      checkInDate: checkInDate,
      checkOutDate: checkOutDate,
      roomCount: roomCount,
      guestCount: guestCount,
      nights: nights,
      unitPricePerNight: unitPricePerNight,
      totalAmount: totalAmount,
      status: status ?? this.status,
      createdAtUtc: createdAtUtc,
      paymentExpiresAtUtc: paymentExpiresAtUtc ?? this.paymentExpiresAtUtc,
      guestFullName: guestFullName,
      guestPhone: guestPhone,
    );
  }

  static Booking fromJson(Object? data) {
    final json = _asMap(data);

    return Booking(
      id: json['id']?.toString() ?? '',
      bookingCode: json['bookingCode']?.toString() ?? '',
      hotelId: json['hotelId']?.toString() ?? '',
      roomTypeId: json['roomTypeId']?.toString() ?? '',
      checkInDate: _parseDate(json['checkInDate']),
      checkOutDate: _parseDate(json['checkOutDate']),
      roomCount: (json['roomCount'] as num?)?.toInt() ?? 1,
      guestCount: (json['guestCount'] as num?)?.toInt() ?? 1,
      nights: (json['nights'] as num?)?.toInt() ?? 1,
      unitPricePerNight: (json['unitPricePerNight'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? '',
      createdAtUtc: DateTime.tryParse(
            json['createdAtUtc']?.toString() ?? '',
          )?.toUtc() ??
          DateTime.now().toUtc(),
      paymentExpiresAtUtc: DateTime.tryParse(
        json['paymentExpiresAtUtc']?.toString() ?? '',
      )?.toUtc(),
      guestFullName: json['guestFullName']?.toString() ?? '',
      guestPhone: json['guestPhone']?.toString() ?? '',
    );
  }
}

class DemoPaymentResult {
  const DemoPaymentResult({
    required this.status,
    required this.message,
    required this.paymentTransactionId,
    required this.provider,
    required this.amount,
    required this.paidAtUtc,
  });

  final String status;
  final String message;
  final String paymentTransactionId;
  final String provider;
  final double amount;
  final DateTime paidAtUtc;

  bool get isProcessed => status.toLowerCase() == 'processed';

  static DemoPaymentResult fromJson(Object? data) {
    final json = _asMap(data);

    return DemoPaymentResult(
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? 'Demo payment completed.',
      paymentTransactionId: json['paymentTransactionId']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      paidAtUtc:
          DateTime.tryParse(json['paidAtUtc']?.toString() ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
    );
  }
}

DateTime _parseDate(Object? value) {
  return DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.now().copyWith(
        hour: 0,
        minute: 0,
        second: 0,
        millisecond: 0,
        microsecond: 0,
      );
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
