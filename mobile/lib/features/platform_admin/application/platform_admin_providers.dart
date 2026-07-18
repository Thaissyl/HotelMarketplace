import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/core_providers.dart';
import '../data/platform_admin_api.dart';
import '../domain/platform_admin_models.dart';

final platformAdminApiProvider = Provider<PlatformAdminApi>((ref) {
  return PlatformAdminApi(ref.watch(apiClientProvider));
});

class AdminUsersQuery {
  const AdminUsersQuery({
    this.role,
    this.searchTerm = '',
  });

  final String? role;
  final String searchTerm;

  @override
  bool operator ==(Object other) {
    return other is AdminUsersQuery &&
        other.role == role &&
        other.searchTerm == searchTerm;
  }

  @override
  int get hashCode => Object.hash(role, searchTerm);
}

final adminUsersProvider =
    FutureProvider.autoDispose.family<List<AdminUser>, AdminUsersQuery>(
  (ref, query) {
    return ref.watch(platformAdminApiProvider).getUsers(
          role: query.role,
          searchTerm: query.searchTerm,
        );
  },
);

final adminUserActivityProvider =
    FutureProvider.autoDispose.family<List<AdminUserActivity>, String>(
  (ref, userId) {
    return ref.watch(platformAdminApiProvider).getUserActivity(userId);
  },
);

final adminFinanceSummaryProvider =
    FutureProvider.autoDispose<List<AdminFinanceSummary>>((ref) {
  return ref.watch(platformAdminApiProvider).getFinanceSummary();
});

final pendingHotelsProvider =
    FutureProvider.autoDispose<List<AdminHotel>>((ref) {
  return ref.watch(platformAdminApiProvider).getPendingHotels();
});

final settlementsProvider =
    FutureProvider.autoDispose<List<AdminSettlement>>((ref) {
  return ref.watch(platformAdminApiProvider).getSettlements();
});

final pendingRefundsProvider =
    FutureProvider.autoDispose<List<AdminRefund>>((ref) {
  return ref
      .watch(platformAdminApiProvider)
      .getRefunds(status: 'PendingReview');
});
