import '../../../core/network/api_client.dart';
import '../domain/platform_admin_models.dart';

class PlatformAdminApi {
  PlatformAdminApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<AdminUser>> getUsers({
    String? role,
    String? searchTerm,
  }) {
    return _apiClient.get<List<AdminUser>>(
      '/api/platform-admin/users',
      queryParameters: {
        if (role != null && role.isNotEmpty) 'role': role,
        if (searchTerm != null && searchTerm.trim().isNotEmpty)
          'searchTerm': searchTerm.trim(),
      },
      decoder: (data) {
        if (data is! List) {
          return const <AdminUser>[];
        }

        return data.map(AdminUser.fromJson).toList(growable: false);
      },
    );
  }

  Future<AdminUser> suspendUser(String userId) {
    return _apiClient.post<AdminUser>(
      '/api/platform-admin/users/$userId/suspend',
      decoder: AdminUser.fromJson,
    );
  }

  Future<AdminUser> reactivateUser(String userId) {
    return _apiClient.post<AdminUser>(
      '/api/platform-admin/users/$userId/reactivate',
      decoder: AdminUser.fromJson,
    );
  }

  Future<List<AdminUserActivity>> getUserActivity(String userId) {
    return _apiClient.get<List<AdminUserActivity>>(
      '/api/platform-admin/users/$userId/activity',
      decoder: (data) {
        if (data is! List) {
          return const <AdminUserActivity>[];
        }

        return data.map(AdminUserActivity.fromJson).toList(growable: false);
      },
    );
  }

  Future<List<AdminFinanceSummary>> getFinanceSummary() {
    return _apiClient.get<List<AdminFinanceSummary>>(
      '/api/platform-admin/finance/summary',
      decoder: (data) {
        if (data is! List) {
          return const <AdminFinanceSummary>[];
        }

        return data.map(AdminFinanceSummary.fromJson).toList(growable: false);
      },
    );
  }

  Future<List<AdminHotel>> getPendingHotels() {
    return _apiClient.get<List<AdminHotel>>(
      '/api/platform-admin/hotels/pending-review',
      decoder: (data) {
        if (data is! List) {
          return const <AdminHotel>[];
        }

        return data.map(AdminHotel.fromJson).toList(growable: false);
      },
    );
  }

  Future<AdminHotel> approveHotel(String hotelId) {
    return _apiClient.post<AdminHotel>(
      '/api/platform-admin/hotels/$hotelId/approve',
      decoder: AdminHotel.fromJson,
    );
  }

  Future<AdminHotel> rejectHotel({
    required String hotelId,
    required String reason,
  }) {
    return _apiClient.post<AdminHotel>(
      '/api/platform-admin/hotels/$hotelId/reject',
      data: {'reason': reason.trim()},
      decoder: AdminHotel.fromJson,
    );
  }

  Future<List<AdminSettlement>> getSettlements({String? status}) {
    return _apiClient.get<List<AdminSettlement>>(
      '/api/platform-admin/settlements',
      queryParameters: {
        if (status != null) 'status': status,
      },
      decoder: (data) {
        if (data is! List) {
          return const <AdminSettlement>[];
        }

        return data.map(AdminSettlement.fromJson).toList(growable: false);
      },
    );
  }

  Future<AdminSettlement> createSettlement({
    required String hotelId,
    required String paymentMode,
    required DateTime fromDate,
    required DateTime toDate,
    String? adminNote,
  }) {
    String apiDate(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    return _apiClient.post<AdminSettlement>(
      '/api/platform-admin/settlements',
      data: {
        'hotelId': hotelId,
        'paymentMode': paymentMode,
        'fromDate': apiDate(fromDate),
        'toDate': apiDate(toDate),
        'adminNote': adminNote?.trim(),
      },
      decoder: AdminSettlement.fromJson,
    );
  }

  Future<List<AdminPaymentTransaction>> getPaymentTransactions({
    String? reconciliationStatus,
  }) {
    return _apiClient.get<List<AdminPaymentTransaction>>(
      '/api/platform-admin/payments',
      queryParameters: {
        if (reconciliationStatus != null)
          'reconciliationStatus': reconciliationStatus,
      },
      decoder: (data) => data is List
          ? data.map(AdminPaymentTransaction.fromJson).toList(growable: false)
          : const <AdminPaymentTransaction>[],
    );
  }

  Future<AdminPaymentTransaction> updatePaymentReconciliation({
    required String paymentTransactionId,
    required String status,
    String? note,
  }) {
    return _apiClient.patch<AdminPaymentTransaction>(
      '/api/platform-admin/payments/$paymentTransactionId/reconciliation',
      data: {'status': status, 'note': note?.trim()},
      decoder: AdminPaymentTransaction.fromJson,
    );
  }

  Future<AdminSettlement> updateSettlementStatus({
    required String settlementId,
    required String status,
    double? settledAmount,
    DateTime? settlementDateUtc,
    String? reference,
    String? adminNote,
  }) {
    return _apiClient.patch<AdminSettlement>(
      '/api/platform-admin/settlements/$settlementId/status',
      data: {
        'status': status,
        'settledAmount': settledAmount,
        'settlementDateUtc': settlementDateUtc?.toUtc().toIso8601String(),
        'reference': reference?.trim(),
        'adminNote': adminNote?.trim(),
      },
      decoder: AdminSettlement.fromJson,
    );
  }

  Future<List<AdminRefund>> getRefunds({String? status}) {
    return _apiClient.get<List<AdminRefund>>(
      '/api/platform-admin/refunds',
      queryParameters: {
        if (status != null) 'status': status,
      },
      decoder: (data) {
        if (data is! List) {
          return const <AdminRefund>[];
        }

        return data.map(AdminRefund.fromJson).toList(growable: false);
      },
    );
  }

  Future<AdminRefund> updateRefundStatus({
    required String refundId,
    required String status,
    double? approvedAmount,
  }) {
    return _apiClient.patch<AdminRefund>(
      '/api/platform-admin/refunds/$refundId/status',
      data: {
        'status': status,
        'approvedAmount': approvedAmount,
      },
      decoder: AdminRefund.fromJson,
    );
  }
}
