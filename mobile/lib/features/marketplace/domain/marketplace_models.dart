import '../../../shared/utils/app_formatters.dart';

class HotelSearchQuery {
  const HotelSearchQuery({
    required this.location,
    required this.checkInDate,
    required this.checkOutDate,
    required this.guestCount,
    required this.roomCount,
  });

  final String location;
  final DateTime checkInDate;
  final DateTime checkOutDate;
  final int guestCount;
  final int roomCount;

  int get nights => checkOutDate.difference(checkInDate).inDays;

  Map<String, dynamic> toQueryParameters() {
    return {
      if (location.trim().isNotEmpty) 'location': location.trim(),
      'checkInDate': AppFormatters.apiDate(checkInDate),
      'checkOutDate': AppFormatters.apiDate(checkOutDate),
      'guestCount': guestCount,
      'roomCount': roomCount,
    };
  }

  HotelSearchQuery copyWith({
    String? location,
    DateTime? checkInDate,
    DateTime? checkOutDate,
    int? guestCount,
    int? roomCount,
  }) {
    return HotelSearchQuery(
      location: location ?? this.location,
      checkInDate: checkInDate ?? this.checkInDate,
      checkOutDate: checkOutDate ?? this.checkOutDate,
      guestCount: guestCount ?? this.guestCount,
      roomCount: roomCount ?? this.roomCount,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HotelSearchQuery &&
        other.location == location &&
        other.checkInDate == checkInDate &&
        other.checkOutDate == checkOutDate &&
        other.guestCount == guestCount &&
        other.roomCount == roomCount;
  }

  @override
  int get hashCode {
    return Object.hash(
      location,
      checkInDate,
      checkOutDate,
      guestCount,
      roomCount,
    );
  }
}

class HotelSearchResult {
  const HotelSearchResult({
    required this.id,
    required this.name,
    required this.city,
    required this.addressLine,
    required this.description,
    required this.coverImageUrl,
    required this.amenityNames,
    required this.minimumPricePerNight,
    required this.availableRoomTypeCount,
  });

  final String id;
  final String name;
  final String city;
  final String addressLine;
  final String? description;
  final String? coverImageUrl;
  final List<String> amenityNames;
  final double minimumPricePerNight;
  final int availableRoomTypeCount;

  static HotelSearchResult fromJson(Object? data) {
    final json = _asMap(data);

    return HotelSearchResult(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      addressLine: json['addressLine']?.toString() ?? '',
      description: json['description']?.toString(),
      coverImageUrl: json['coverImageUrl']?.toString(),
      amenityNames: _stringList(json['amenityNames']),
      minimumPricePerNight:
          (json['minimumPricePerNight'] as num?)?.toDouble() ?? 0,
      availableRoomTypeCount:
          (json['availableRoomTypeCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class HotelDetail {
  const HotelDetail({
    required this.id,
    required this.name,
    required this.city,
    required this.addressLine,
    required this.description,
    required this.contactEmail,
    required this.contactPhone,
    required this.checkInDate,
    required this.checkOutDate,
    required this.guestCount,
    required this.roomCount,
    required this.images,
    required this.amenities,
    required this.cancellationPolicy,
    required this.availableRoomTypes,
  });

  final String id;
  final String name;
  final String city;
  final String addressLine;
  final String? description;
  final String contactEmail;
  final String contactPhone;
  final DateTime checkInDate;
  final DateTime checkOutDate;
  final int guestCount;
  final int roomCount;
  final List<HotelImage> images;
  final List<HotelAmenity> amenities;
  final CancellationPolicy? cancellationPolicy;
  final List<AvailableRoomType> availableRoomTypes;

  static HotelDetail fromJson(Object? data) {
    final json = _asMap(data);
    final roomTypes = json['availableRoomTypes'];

    return HotelDetail(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      addressLine: json['addressLine']?.toString() ?? '',
      description: json['description']?.toString(),
      contactEmail: json['contactEmail']?.toString() ?? '',
      contactPhone: json['contactPhone']?.toString() ?? '',
      checkInDate: _parseDate(json['checkInDate']),
      checkOutDate: _parseDate(json['checkOutDate']),
      guestCount: (json['guestCount'] as num?)?.toInt() ?? 1,
      roomCount: (json['roomCount'] as num?)?.toInt() ?? 1,
      images: _modelList(json['images'], HotelImage.fromJson),
      amenities: _modelList(json['amenities'], HotelAmenity.fromJson),
      cancellationPolicy: json['cancellationPolicy'] == null
          ? null
          : CancellationPolicy.fromJson(json['cancellationPolicy']),
      availableRoomTypes: roomTypes is List
          ? roomTypes.map(AvailableRoomType.fromJson).toList(growable: false)
          : const <AvailableRoomType>[],
    );
  }
}

class AvailableRoomType {
  const AvailableRoomType({
    required this.id,
    required this.name,
    required this.adultCapacity,
    required this.childCapacity,
    required this.totalGuestCapacity,
    required this.basePricePerNight,
    required this.availableRoomCount,
    required this.requestedRoomCount,
    required this.nights,
    required this.totalPriceForStay,
    required this.description,
    required this.facilities,
  });

  final String id;
  final String name;
  final int adultCapacity;
  final int childCapacity;
  final int totalGuestCapacity;
  final double basePricePerNight;
  final int availableRoomCount;
  final int requestedRoomCount;
  final int nights;
  final double totalPriceForStay;
  final String? description;
  final String? facilities;

  static AvailableRoomType fromJson(Object? data) {
    final json = _asMap(data);

    return AvailableRoomType(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      adultCapacity: (json['adultCapacity'] as num?)?.toInt() ?? 0,
      childCapacity: (json['childCapacity'] as num?)?.toInt() ?? 0,
      totalGuestCapacity: (json['totalGuestCapacity'] as num?)?.toInt() ?? 0,
      basePricePerNight: (json['basePricePerNight'] as num?)?.toDouble() ?? 0,
      availableRoomCount: (json['availableRoomCount'] as num?)?.toInt() ?? 0,
      requestedRoomCount: (json['requestedRoomCount'] as num?)?.toInt() ?? 0,
      nights: (json['nights'] as num?)?.toInt() ?? 1,
      totalPriceForStay: (json['totalPriceForStay'] as num?)?.toDouble() ?? 0,
      description: json['description']?.toString(),
      facilities: json['facilities']?.toString(),
    );
  }
}

class HotelImage {
  const HotelImage({
    required this.id,
    required this.imageUrl,
    required this.displayOrder,
  });

  final String id;
  final String imageUrl;
  final int displayOrder;

  static HotelImage fromJson(Object? data) {
    final json = _asMap(data);
    return HotelImage(
      id: json['id']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

class HotelAmenity {
  const HotelAmenity({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
  });

  final String id;
  final String code;
  final String name;
  final String type;

  static HotelAmenity fromJson(Object? data) {
    final json = _asMap(data);
    return HotelAmenity(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
    );
  }
}

class CancellationPolicy {
  const CancellationPolicy({
    required this.id,
    required this.name,
    required this.freeCancellationHours,
    required this.refundPercentage,
    required this.description,
  });

  final String id;
  final String name;
  final int freeCancellationHours;
  final double refundPercentage;
  final String? description;

  static CancellationPolicy fromJson(Object? data) {
    final json = _asMap(data);
    return CancellationPolicy(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      freeCancellationHours:
          (json['freeCancellationHours'] as num?)?.toInt() ?? 0,
      refundPercentage: (json['refundPercentage'] as num?)?.toDouble() ?? 0,
      description: json['description']?.toString(),
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

List<String> _stringList(Object? data) {
  return data is List
      ? data.map((value) => value.toString()).toList(growable: false)
      : const <String>[];
}

List<T> _modelList<T>(Object? data, T Function(Object?) parser) {
  return data is List
      ? data.map(parser).toList(growable: false)
      : List<T>.empty(growable: false);
}
