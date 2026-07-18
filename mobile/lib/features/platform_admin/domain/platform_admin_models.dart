class AdminFinanceSummary {
  const AdminFinanceSummary({
    required this.hotelId,
    required this.hotelName,
    required this.grossBookingRevenue,
    required this.platformCommission,
    required this.hotelNetReceivable,
    required this.successfulBookingCount,
  });

  final String hotelId;
  final String hotelName;
  final double grossBookingRevenue;
  final double platformCommission;
  final double hotelNetReceivable;
  final int successfulBookingCount;

  static AdminFinanceSummary fromJson(Object? data) {
    final json = _asMap(data);
    return AdminFinanceSummary(
      hotelId: json['hotelId']?.toString() ?? '',
      hotelName: json['hotelName']?.toString() ?? '',
      grossBookingRevenue:
          (json['grossBookingRevenue'] as num?)?.toDouble() ?? 0,
      platformCommission: (json['platformCommission'] as num?)?.toDouble() ?? 0,
      hotelNetReceivable: (json['hotelNetReceivable'] as num?)?.toDouble() ?? 0,
      successfulBookingCount:
          (json['successfulBookingCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminHotel {
  const AdminHotel({
    required this.id,
    required this.name,
    required this.city,
    required this.addressLine,
    required this.contactEmail,
    required this.contactPhone,
    required this.approvalStatus,
    required this.publicationStatus,
    required this.defaultCommissionRate,
    required this.createdAtUtc,
  });

  final String id;
  final String name;
  final String city;
  final String addressLine;
  final String contactEmail;
  final String contactPhone;
  final String approvalStatus;
  final String publicationStatus;
  final double defaultCommissionRate;
  final DateTime createdAtUtc;

  static AdminHotel fromJson(Object? data) {
    final json = _asMap(data);
    return AdminHotel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      addressLine: json['addressLine']?.toString() ?? '',
      contactEmail: json['contactEmail']?.toString() ?? '',
      contactPhone: json['contactPhone']?.toString() ?? '',
      approvalStatus: json['approvalStatus']?.toString() ?? '',
      publicationStatus: json['publicationStatus']?.toString() ?? '',
      defaultCommissionRate:
          (json['defaultCommissionRate'] as num?)?.toDouble() ?? 0,
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc']?.toString() ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
    );
  }
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phoneNumber,
    required this.status,
    required this.roles,
    required this.hotelIds,
    required this.createdAtUtc,
  });

  final String id;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final String status;
  final List<String> roles;
  final List<String> hotelIds;
  final DateTime createdAtUtc;

  static AdminUser fromJson(Object? data) {
    final json = _asMap(data);
    return AdminUser(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString(),
      status: json['status']?.toString() ?? '',
      roles: _stringList(json['roles']),
      hotelIds: _stringList(json['hotelIds']),
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc']?.toString() ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
    );
  }
}

class AdminUserActivity {
  const AdminUserActivity({
    required this.id,
    required this.actorUserAccountId,
    required this.actorEmail,
    required this.actionType,
    required this.targetEntityType,
    required this.targetEntityId,
    required this.summary,
    required this.actionTimestampUtc,
  });

  final String id;
  final String actorUserAccountId;
  final String actorEmail;
  final String actionType;
  final String targetEntityType;
  final String targetEntityId;
  final String summary;
  final DateTime actionTimestampUtc;

  static AdminUserActivity fromJson(Object? data) {
    final json = _asMap(data);
    return AdminUserActivity(
      id: json['id']?.toString() ?? '',
      actorUserAccountId: json['actorUserAccountId']?.toString() ?? '',
      actorEmail: json['actorEmail']?.toString() ?? '',
      actionType: json['actionType']?.toString() ?? '',
      targetEntityType: json['targetEntityType']?.toString() ?? '',
      targetEntityId: json['targetEntityId']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      actionTimestampUtc:
          DateTime.tryParse(json['actionTimestampUtc']?.toString() ?? '')
                  ?.toUtc() ??
              DateTime.now().toUtc(),
    );
  }
}

class AdminSettlement {
  const AdminSettlement({
    required this.id,
    required this.hotelId,
    required this.hotelName,
    required this.settlementType,
    required this.totalAmount,
    required this.status,
    required this.adminNote,
    required this.createdAtUtc,
    required this.items,
  });

  final String id;
  final String hotelId;
  final String hotelName;
  final String settlementType;
  final double totalAmount;
  final String status;
  final String? adminNote;
  final DateTime createdAtUtc;
  final List<AdminSettlementItem> items;

  static AdminSettlement fromJson(Object? data) {
    final json = _asMap(data);
    final items = json['items'];
    return AdminSettlement(
      id: json['id']?.toString() ?? '',
      hotelId: json['hotelId']?.toString() ?? '',
      hotelName: json['hotelName']?.toString() ?? '',
      settlementType: json['settlementType']?.toString() ?? '',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? '',
      adminNote: json['adminNote']?.toString(),
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc']?.toString() ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
      items: items is List
          ? items.map(AdminSettlementItem.fromJson).toList(growable: false)
          : const <AdminSettlementItem>[],
    );
  }
}

class AdminSettlementItem {
  const AdminSettlementItem({
    required this.id,
    required this.amount,
    required this.status,
  });

  final String id;
  final double amount;
  final String status;

  static AdminSettlementItem fromJson(Object? data) {
    final json = _asMap(data);
    return AdminSettlementItem(
      id: json['id']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? '',
    );
  }
}

class AdminRefund {
  const AdminRefund({
    required this.id,
    required this.hotelId,
    required this.hotelName,
    required this.bookingId,
    required this.requestedAmount,
    required this.approvedAmount,
    required this.reason,
    required this.status,
    required this.createdAtUtc,
  });

  final String id;
  final String hotelId;
  final String hotelName;
  final String bookingId;
  final double requestedAmount;
  final double approvedAmount;
  final String reason;
  final String status;
  final DateTime createdAtUtc;

  static AdminRefund fromJson(Object? data) {
    final json = _asMap(data);
    return AdminRefund(
      id: json['id']?.toString() ?? '',
      hotelId: json['hotelId']?.toString() ?? '',
      hotelName: json['hotelName']?.toString() ?? '',
      bookingId: json['bookingId']?.toString() ?? '',
      requestedAmount: (json['requestedAmount'] as num?)?.toDouble() ?? 0,
      approvedAmount: (json['approvedAmount'] as num?)?.toDouble() ?? 0,
      reason: json['reason']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc']?.toString() ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
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

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }

  return value.map((item) => item.toString()).toList(growable: false);
}
