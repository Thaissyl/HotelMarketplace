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
    required this.paymentMode,
  });

  final String hotelId;
  final String roomTypeId;
  final DateTime checkInDate;
  final DateTime checkOutDate;
  final int roomCount;
  final int guestCount;
  final String guestFullName;
  final String guestPhone;
  final String paymentMode;

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
      'paymentMode': paymentMode,
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
    required this.paymentMode,
    required this.status,
    required this.createdAtUtc,
    required this.paymentExpiresAtUtc,
    required this.guestFullName,
    required this.guestPhone,
    this.refundStatus,
    this.refundRequestedAmount,
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
  final String paymentMode;
  final String status;
  final DateTime createdAtUtc;
  final DateTime? paymentExpiresAtUtc;
  final String guestFullName;
  final String guestPhone;
  final String? refundStatus;
  final double? refundRequestedAmount;

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
      paymentMode: paymentMode,
      status: status ?? this.status,
      createdAtUtc: createdAtUtc,
      paymentExpiresAtUtc: paymentExpiresAtUtc ?? this.paymentExpiresAtUtc,
      guestFullName: guestFullName,
      guestPhone: guestPhone,
      refundStatus: refundStatus,
      refundRequestedAmount: refundRequestedAmount,
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
      paymentMode: json['paymentMode']?.toString() ?? 'PlatformCollect',
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
      refundStatus: json['refundStatus']?.toString(),
      refundRequestedAmount:
          (json['refundRequestedAmount'] as num?)?.toDouble(),
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

class BookingCancellationQuote {
  const BookingCancellationQuote({
    required this.bookingId,
    required this.canCancel,
    required this.isPaid,
    required this.policyName,
    required this.freeCancellationHours,
    required this.refundPercentage,
    required this.freeCancellationDeadlineUtc,
    required this.isWithinFreeCancellationWindow,
    required this.estimatedRefundAmount,
    required this.summary,
  });

  final String bookingId;
  final bool canCancel;
  final bool isPaid;
  final String? policyName;
  final int? freeCancellationHours;
  final double refundPercentage;
  final DateTime? freeCancellationDeadlineUtc;
  final bool isWithinFreeCancellationWindow;
  final double estimatedRefundAmount;
  final String summary;

  static BookingCancellationQuote fromJson(Object? data) {
    final json = _asMap(data);
    return BookingCancellationQuote(
      bookingId: json['bookingId']?.toString() ?? '',
      canCancel: json['canCancel'] == true,
      isPaid: json['isPaid'] == true,
      policyName: json['policyName']?.toString(),
      freeCancellationHours: (json['freeCancellationHours'] as num?)?.toInt(),
      refundPercentage: (json['refundPercentage'] as num?)?.toDouble() ?? 0,
      freeCancellationDeadlineUtc: DateTime.tryParse(
        json['freeCancellationDeadlineUtc']?.toString() ?? '',
      )?.toUtc(),
      isWithinFreeCancellationWindow:
          json['isWithinFreeCancellationWindow'] == true,
      estimatedRefundAmount:
          (json['estimatedRefundAmount'] as num?)?.toDouble() ?? 0,
      summary: json['summary']?.toString() ?? '',
    );
  }
}

class BookingCancellationResult {
  const BookingCancellationResult({
    required this.bookingId,
    required this.bookingStatus,
    required this.cancelledAtUtc,
    required this.cancellationReason,
    required this.refundRequestedAmount,
    required this.refundRecordId,
    required this.refundStatus,
    required this.summary,
  });

  final String bookingId;
  final String bookingStatus;
  final DateTime cancelledAtUtc;
  final String cancellationReason;
  final double refundRequestedAmount;
  final String? refundRecordId;
  final String? refundStatus;
  final String summary;

  static BookingCancellationResult fromJson(Object? data) {
    final json = _asMap(data);
    return BookingCancellationResult(
      bookingId: json['bookingId']?.toString() ?? '',
      bookingStatus: json['bookingStatus']?.toString() ?? 'Cancelled',
      cancelledAtUtc:
          DateTime.tryParse(json['cancelledAtUtc']?.toString() ?? '')
                  ?.toUtc() ??
              DateTime.now().toUtc(),
      cancellationReason: json['cancellationReason']?.toString() ?? '',
      refundRequestedAmount:
          (json['refundRequestedAmount'] as num?)?.toDouble() ?? 0,
      refundRecordId: json['refundRecordId']?.toString(),
      refundStatus: json['refundStatus']?.toString(),
      summary: json['summary']?.toString() ?? '',
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
