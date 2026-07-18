import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';

class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(Ref ref) {
    _subscription = ref.listen(
      authControllerProvider,
      (previous, next) => notifyListeners(),
    );
  }

  late final ProviderSubscription<Object?> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
