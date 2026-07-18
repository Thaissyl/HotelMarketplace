import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/core_providers.dart';
import '../data/customer_account_api.dart';
import '../domain/customer_account_models.dart';

final customerAccountApiProvider = Provider<CustomerAccountApi>((ref) {
  return CustomerAccountApi(ref.watch(apiClientProvider));
});

final customerProfileProvider = FutureProvider.autoDispose<CustomerProfile>((ref) {
  return ref.watch(customerAccountApiProvider).getProfile();
});
