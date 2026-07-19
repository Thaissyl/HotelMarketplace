import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/auth/domain/auth_models.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/account/presentation/account_settings_screen.dart';
import '../../features/bookings/domain/booking_draft.dart';
import '../../features/bookings/domain/booking_models.dart';
import '../../features/bookings/presentation/booking_confirmation_screen.dart';
import '../../features/bookings/presentation/pending_payment_screen.dart';
import '../../features/customer/presentation/customer_home_screen.dart';
import '../../features/marketplace/application/marketplace_providers.dart';
import '../../features/marketplace/domain/marketplace_models.dart';
import '../../features/marketplace/presentation/hotel_detail_screen.dart';
import '../../features/marketplace/presentation/marketplace_screen.dart';
import '../../features/operations/presentation/operations_dashboard_screen.dart';
import '../../features/platform_admin/presentation/platform_admin_dashboard_screen.dart';
import '../../features/system/presentation/api_connection_screen.dart';
import '../../features/system/presentation/splash_screen.dart';
import 'go_router_refresh_notifier.dart';

final goRouterRefreshNotifierProvider = Provider<GoRouterRefreshNotifier>((
  ref,
) {
  final notifier = GoRouterRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: SplashScreen.routePath,
    refreshListenable: ref.watch(goRouterRefreshNotifierProvider),
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      final isSplash = location == SplashScreen.routePath;
      final isLogin = location == LoginScreen.routePath;
      final isRegister = location == RegisterScreen.routePath;
      final isAuthRoute = isLogin || isRegister;
      final isPublicMarketplaceRoute =
          location == MarketplaceScreen.routePath ||
              location == HotelDetailScreen.routePath;
      final isCustomerHomeRoute = location == CustomerHomeScreen.routePath;
      final isCustomerOnlyRoute = isCustomerHomeRoute ||
          location == BookingConfirmationScreen.routePath ||
          location == PendingPaymentScreen.routePath;
      final isOperationsRoute = location == OperationsDashboardScreen.routePath;
      final isPlatformAdminRoute =
          location == PlatformAdminDashboardScreen.routePath;
      final userSession = authState.userSession;
      final landingPath = _landingPathForRoles(userSession?.roles ?? const []);
      final isPlatformAdmin = _isPlatformAdmin(userSession?.roles ?? const []);
      final hasHotelOperationsAccess =
          _hasHotelOperationsAccess(userSession?.roles ?? const []);
      final isCustomer = _isCustomer(userSession?.roles ?? const []);

      if (authState.status == AuthStatus.checking) {
        return isSplash ? null : SplashScreen.routePath;
      }

      if (authState.isAuthenticated) {
        if (isPlatformAdminRoute && !isPlatformAdmin) {
          return landingPath;
        }

        if (isOperationsRoute && !hasHotelOperationsAccess) {
          return landingPath;
        }

        if (isCustomerOnlyRoute && !isCustomer) {
          return landingPath;
        }

        return isAuthRoute || isSplash ? landingPath : null;
      }

      if (isSplash) {
        return MarketplaceScreen.routePath;
      }

      if (!isAuthRoute && !isPublicMarketplaceRoute) {
        return LoginScreen.routePath;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: SplashScreen.routePath,
        name: SplashScreen.routeName,
        pageBuilder: (context, state) => _fadePage(
          key: state.pageKey,
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: LoginScreen.routePath,
        name: LoginScreen.routeName,
        pageBuilder: (context, state) => _slideFadePage(
          key: state.pageKey,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: RegisterScreen.routePath,
        name: RegisterScreen.routeName,
        pageBuilder: (context, state) => _slideFadePage(
          key: state.pageKey,
          child: const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: AccountSettingsScreen.routePath,
        name: AccountSettingsScreen.routeName,
        pageBuilder: (context, state) => _slideFadePage(
          key: state.pageKey,
          child: const AccountSettingsScreen(),
        ),
      ),
      GoRoute(
        path: CustomerHomeScreen.routePath,
        name: CustomerHomeScreen.routeName,
        pageBuilder: (context, state) => _slideFadePage(
          key: state.pageKey,
          child: const CustomerHomeScreen(),
        ),
      ),
      GoRoute(
        path: MarketplaceScreen.routePath,
        name: MarketplaceScreen.routeName,
        pageBuilder: (context, state) => _slideFadePage(
          key: state.pageKey,
          child: const MarketplaceScreen(),
        ),
      ),
      GoRoute(
        path: HotelDetailScreen.routePath,
        name: HotelDetailScreen.routeName,
        pageBuilder: (context, state) {
          final hotelId = state.pathParameters['hotelId'] ?? '';
          final query = state.extra is HotelSearchQuery
              ? state.extra! as HotelSearchQuery
              : ref.read(hotelSearchQueryProvider);

          return _slideFadePage(
            key: state.pageKey,
            child: HotelDetailScreen(
              hotelId: hotelId,
              query: query,
            ),
          );
        },
      ),
      GoRoute(
        path: BookingConfirmationScreen.routePath,
        name: BookingConfirmationScreen.routeName,
        pageBuilder: (context, state) {
          final extra = state.extra;
          if (extra is! BookingDraft) {
            return _slideFadePage(
              key: state.pageKey,
              child: const CustomerHomeScreen(),
            );
          }

          return _slideFadePage(
            key: state.pageKey,
            child: BookingConfirmationScreen(draft: extra),
          );
        },
      ),
      GoRoute(
        path: PendingPaymentScreen.routePath,
        name: PendingPaymentScreen.routeName,
        pageBuilder: (context, state) {
          final extra = state.extra;
          if (extra is! Booking) {
            return _slideFadePage(
              key: state.pageKey,
              child: const CustomerHomeScreen(),
            );
          }

          return _slideFadePage(
            key: state.pageKey,
            child: PendingPaymentScreen(booking: extra),
          );
        },
      ),
      GoRoute(
        path: OperationsDashboardScreen.routePath,
        name: OperationsDashboardScreen.routeName,
        pageBuilder: (context, state) => _slideFadePage(
          key: state.pageKey,
          child: const OperationsDashboardScreen(),
        ),
      ),
      GoRoute(
        path: PlatformAdminDashboardScreen.routePath,
        name: PlatformAdminDashboardScreen.routeName,
        pageBuilder: (context, state) => _slideFadePage(
          key: state.pageKey,
          child: const PlatformAdminDashboardScreen(),
        ),
      ),
      GoRoute(
        path: ApiConnectionScreen.routePath,
        name: ApiConnectionScreen.routeName,
        pageBuilder: (context, state) => _slideFadePage(
          key: state.pageKey,
          child: const ApiConnectionScreen(),
        ),
      ),
    ],
  );
});

String _landingPathForRoles(List<String> roles) {
  if (_isPlatformAdmin(roles)) {
    return PlatformAdminDashboardScreen.routePath;
  }

  if (_hasHotelOperationsAccess(roles)) {
    return OperationsDashboardScreen.routePath;
  }

  return CustomerHomeScreen.routePath;
}

bool _isCustomer(List<String> roles) {
  return roles.contains(UserRoleCode.customer.apiValue);
}

bool _isPlatformAdmin(List<String> roles) {
  return roles.contains(UserRoleCode.platformAdministrator.apiValue);
}

bool _hasHotelOperationsAccess(List<String> roles) {
  return roles.any((role) {
    return role == UserRoleCode.propertyOwner.apiValue ||
        role == UserRoleCode.hotelManager.apiValue ||
        role == UserRoleCode.receptionist.apiValue ||
        role == UserRoleCode.housekeepingStaff.apiValue ||
        role == UserRoleCode.maintenanceStaff.apiValue;
  });
}

CustomTransitionPage<void> _fadePage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
        child: child,
      );
    },
  );
}

CustomTransitionPage<void> _slideFadePage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return FadeTransition(
        opacity: curvedAnimation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.04, 0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        ),
      );
    },
  );
}
