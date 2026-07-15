import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/core_providers.dart';
import '../data/platform_admin_api.dart';
import '../domain/platform_admin_models.dart';

final platformAdminApiProvider = Provider<PlatformAdminApi>((ref) {
  return PlatformAdminApi(ref.watch(apiClientProvider));
});

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
