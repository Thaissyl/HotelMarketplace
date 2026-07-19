import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../../features/auth/presentation/auth_form_validators.dart';
import '../../../features/bookings/application/booking_controller.dart';
import '../../../features/bookings/domain/booking_models.dart';
import '../../../features/marketplace/application/marketplace_providers.dart';
import '../../../features/marketplace/presentation/hotel_detail_screen.dart';
import '../../../features/marketplace/presentation/marketplace_screen.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/app_text_form_field.dart';
import '../application/customer_account_providers.dart';
import '../application/customer_state.dart';
import '../domain/customer_account_models.dart';

class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  static const String routeName = 'customer-home';
  static const String routePath = '/customer';

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      try {
        await ref.read(customerStateProvider.notifier).loadEngagement();
      } catch (error) {
        if (mounted) {
          AppErrorPresenter.showSnackBar(context, error);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref
        .watch(customerStateProvider)
        .notifications
        .where((item) => item.unread)
        .length;

    final pages = [
      const MarketplaceScreen(showAppBar: false),
      const _SavedHotelsTab(),
      const _TripsTab(),
      const _NotificationsTab(),
      const _SettingsTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForIndex(_selectedIndex)),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () {
              ref.read(authControllerProvider.notifier).logout();
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) async {
          setState(() => _selectedIndex = index);
          if (index == 3) {
            try {
              await ref.read(customerStateProvider.notifier).loadEngagement();
              await ref
                  .read(customerStateProvider.notifier)
                  .markNotificationsRead();
            } catch (error) {
              if (context.mounted) {
                AppErrorPresenter.showSnackBar(context, error);
              }
            }
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.search_rounded),
            selectedIcon: Icon(Icons.search_rounded),
            label: 'Search',
          ),
          const NavigationDestination(
            icon: Icon(Icons.favorite_border_rounded),
            selectedIcon: Icon(Icons.favorite_rounded),
            label: 'Saved',
          ),
          const NavigationDestination(
            icon: Icon(Icons.luggage_outlined),
            selectedIcon: Icon(Icons.luggage_rounded),
            label: 'Trips',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(unreadCount.toString()),
              child: const Icon(Icons.notifications_none_rounded),
            ),
            selectedIcon: const Icon(Icons.notifications_rounded),
            label: 'Alerts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  String _titleForIndex(int index) {
    return switch (index) {
      1 => 'Saved hotels',
      2 => 'My trips',
      3 => 'Notifications',
      4 => 'Settings',
      _ => 'Find stays',
    };
  }
}

class _SavedHotelsTab extends ConsumerWidget {
  const _SavedHotelsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedHotels = ref.watch(customerStateProvider).savedHotels;
    final query = ref.watch(hotelSearchQueryProvider);

    if (savedHotels.isEmpty) {
      return const _EmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'No saved hotels yet',
        body: 'Tap the heart on a hotel card or detail page to save it here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.xl),
      itemBuilder: (context, index) {
        final hotel = savedHotels[index];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              child: Icon(Icons.hotel_rounded),
            ),
            title: Text(hotel.name),
            subtitle: Text('${hotel.city} - ${hotel.addressLine}'),
            trailing: Text(
              hotel.minimumPricePerNight <= 0
                  ? 'View'
                  : AppFormatters.money(hotel.minimumPricePerNight),
            ),
            onTap: () {
              context.push(
                HotelDetailScreen.pathFor(hotel.id),
                extra: query,
              );
            },
          ),
        );
      },
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemCount: savedHotels.length,
    );
  }
}

class _TripsTab extends ConsumerWidget {
  const _TripsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localBookings = ref.watch(customerStateProvider).bookings;
    final bookingsState = ref.watch(myBookingsProvider);

    return bookingsState.when(
      data: (backendBookings) {
        final bookings = _mergeBookings(backendBookings, localBookings);

        if (bookings.isEmpty) {
          return const _EmptyState(
            icon: Icons.luggage_outlined,
            title: 'No trips yet',
            body: 'Your reservations and confirmed bookings will appear here.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myBookingsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.xl),
            itemBuilder: (context, index) {
              final booking = bookings[index];
              return _TripCard(
                booking: booking,
                onTap: () => _showBookingDetails(context, ref, booking),
              );
            },
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.sm),
            itemCount: bookings.length,
          ),
        );
      },
      error: (error, stackTrace) {
        if (localBookings.isNotEmpty) {
          return _LocalTripFallback(
            bookings: localBookings,
            onViewDetails: (booking) =>
                _showBookingDetails(context, ref, booking),
            onRetry: () => ref.invalidate(myBookingsProvider),
          );
        }

        return _ErrorState(
          icon: Icons.cloud_off_rounded,
          title: 'Unable to load trips',
          body: AppErrorPresenter.friendlyMessage(error),
          onRetry: () => ref.invalidate(myBookingsProvider),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  List<Booking> _mergeBookings(List<Booking> backend, List<Booking> local) {
    final byId = <String, Booking>{};
    for (final booking in local) {
      byId[booking.id] = booking;
    }
    for (final booking in backend) {
      byId[booking.id] = booking;
    }

    final bookings = byId.values.toList(growable: false);
    bookings.sort(
      (left, right) => right.createdAtUtc.compareTo(left.createdAtUtc),
    );
    return bookings;
  }

  void _showBookingDetails(
    BuildContext context,
    WidgetRef ref,
    Booking booking,
  ) {
    final parentContext = context;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.xl),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Booking ${booking.bookingCode}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    _StatusPill(status: booking.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _BookingDetailRow(
                  label: 'Guest',
                  value: booking.guestFullName,
                ),
                _BookingDetailRow(
                  label: 'Booked at',
                  value: AppFormatters.displayDate(booking.createdAtUtc),
                ),
                _BookingDetailRow(
                  label: 'Check-in',
                  value: AppFormatters.displayDate(booking.checkInDate),
                ),
                _BookingDetailRow(
                  label: 'Check-out',
                  value: AppFormatters.displayDate(booking.checkOutDate),
                ),
                _BookingDetailRow(label: 'Nights', value: '${booking.nights}'),
                _BookingDetailRow(
                  label: 'Guests',
                  value: '${booking.guestCount}',
                ),
                _BookingDetailRow(
                  label: 'Rooms',
                  value: '${booking.roomCount}',
                ),
                _BookingDetailRow(
                  label: 'Nightly rate',
                  value: AppFormatters.money(booking.unitPricePerNight),
                ),
                _BookingDetailRow(
                  label: 'Booking total',
                  value: AppFormatters.money(booking.totalAmount),
                ),
                if (booking.paymentExpiresAtUtc != null)
                  _BookingDetailRow(
                    label: 'Payment deadline',
                    value: AppFormatters.displayDate(
                      booking.paymentExpiresAtUtc!,
                    ),
                  ),
                if (booking.refundStatus != null) ...[
                  _BookingDetailRow(
                    label: 'Refund status',
                    value: booking.refundStatus!,
                  ),
                  _BookingDetailRow(
                    label: 'Refund requested',
                    value: AppFormatters.money(
                      booking.refundRequestedAmount ?? 0,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ),
                    if (booking.status == 'PendingPayment' ||
                        booking.status == 'Confirmed') ...[
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await _showCancellationFlow(
                              parentContext,
                              ref,
                              booking,
                            );
                          },
                          icon: const Icon(Icons.event_busy_rounded),
                          label: const Text('Cancel booking'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCancellationFlow(
    BuildContext context,
    WidgetRef ref,
    Booking booking,
  ) async {
    try {
      final api = ref.read(bookingApiProvider);
      final quote = await api.getCancellationQuote(booking.id);
      if (!context.mounted) {
        return;
      }

      final reason = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => _CancellationConfirmationSheet(
          booking: booking,
          quote: quote,
        ),
      );

      if (reason == null || !context.mounted) {
        return;
      }

      final result = await api.cancelBooking(
        bookingId: booking.id,
        reason: reason,
      );
      ref.read(customerStateProvider.notifier).markBookingCancelled(booking.id);
      ref.invalidate(myBookingsProvider);

      if (context.mounted) {
        AppErrorPresenter.showSnackBar(context, result.summary);
      }
    } catch (error) {
      if (context.mounted) {
        await AppErrorPresenter.showBottomSheet(
          context,
          error,
          title: 'Cancellation not completed',
        );
      }
    }
  }
}

class _CancellationConfirmationSheet extends StatefulWidget {
  const _CancellationConfirmationSheet({
    required this.booking,
    required this.quote,
  });

  final Booking booking;
  final BookingCancellationQuote quote;

  @override
  State<_CancellationConfirmationSheet> createState() =>
      _CancellationConfirmationSheetState();
}

class _CancellationConfirmationSheetState
    extends State<_CancellationConfirmationSheet> {
  final _reasonController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _confirm() {
    final reason = _reasonController.text.trim();
    if (reason.length < 3) {
      setState(() => _errorText = 'Enter a clear cancellation reason.');
      return;
    }

    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    final quote = widget.quote;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cancel ${widget.booking.bookingCode}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(quote.summary),
            const SizedBox(height: AppSpacing.lg),
            _BookingDetailRow(
              label: 'Policy',
              value: quote.policyName ?? 'No refundable policy configured',
            ),
            _BookingDetailRow(
              label: 'Payment collected',
              value: quote.isPaid ? 'Yes' : 'No',
            ),
            _BookingDetailRow(
              label: 'Estimated refund',
              value: AppFormatters.money(quote.estimatedRefundAmount),
            ),
            if (quote.freeCancellationDeadlineUtc != null)
              _BookingDetailRow(
                label: 'Refund deadline',
                value: AppFormatters.displayDate(
                  quote.freeCancellationDeadlineUtc!,
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            AppTextFormField(
              controller: _reasonController,
              labelText: 'Cancellation reason',
              errorText: _errorText,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: quote.canCancel ? _confirm : null,
              icon: const Icon(Icons.event_busy_rounded),
              label: const Text('Confirm cancellation'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingDetailRow extends StatelessWidget {
  const _BookingDetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.booking,
    required this.onTap,
  });

  final dynamic booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Booking ${booking.bookingCode}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  _StatusPill(status: booking.status),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${AppFormatters.displayDate(booking.checkInDate)} - ${AppFormatters.displayDate(booking.checkOutDate)}',
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${booking.roomCount} room - ${booking.guestCount} guest${booking.guestCount == 1 ? '' : 's'} - ${AppFormatters.money(booking.totalAmount)}',
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tap to view stay and payment details',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalTripFallback extends StatelessWidget {
  const _LocalTripFallback({
    required this.bookings,
    required this.onViewDetails,
    required this.onRetry,
  });

  final List<dynamic> bookings;
  final ValueChanged<dynamic> onViewDetails;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.xl),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_off_rounded),
              title: const Text('Showing local trips'),
              subtitle: const Text('Backend trip history is unavailable.'),
              trailing: IconButton(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
          );
        }

        final booking = bookings[index - 1];
        return _TripCard(
          booking: booking,
          onTap: () => onViewDetails(booking),
        );
      },
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemCount: bookings.length + 1,
    );
  }
}

class _NotificationsTab extends ConsumerWidget {
  const _NotificationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(customerStateProvider).notifications;

    if (notifications.isEmpty) {
      return const _EmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'No notifications',
        body: 'Important booking and account updates will appear here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.xl),
      itemBuilder: (context, index) {
        final item = notifications[index];
        return Card(
          child: ListTile(
            leading: Icon(
              item.unread
                  ? Icons.mark_email_unread_rounded
                  : Icons.mark_email_read_rounded,
              color: item.unread ? AppColors.brand : null,
            ),
            title: Text(item.title),
            subtitle: Text(item.body),
            trailing: Text(item.createdLabel),
          ),
        );
      },
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemCount: notifications.length,
    );
  }
}

class _SettingsTab extends ConsumerStatefulWidget {
  const _SettingsTab();

  @override
  ConsumerState<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<_SettingsTab> {
  final _formKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _profileHydrated = false;
  bool _savingProfile = false;
  bool _changingPassword = false;

  @override
  void initState() {
    super.initState();
    final customerState = ref.read(customerStateProvider);
    final session = ref.read(authControllerProvider).userSession;
    _nameController = TextEditingController(
      text: customerState.displayName.isEmpty
          ? session?.email.split('@').first ?? ''
          : customerState.displayName,
    );
    _phoneController = TextEditingController(text: customerState.phoneNumber);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() => _savingProfile = true);
    try {
      final profile = await ref.read(customerAccountApiProvider).updateProfile(
            UpdateCustomerProfileRequest(
              fullName: _nameController.text,
              phoneNumber: _phoneController.text,
            ),
          );
      ref.invalidate(customerProfileProvider);
      ref.read(customerStateProvider.notifier).updateProfile(
            displayName: profile.fullName,
            phoneNumber: profile.phoneNumber ?? '',
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Profile updated.')),
          );
      }
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _savingProfile = false);
      }
    }
  }

  Future<void> _changePassword() async {
    if (_passwordFormKey.currentState?.validate() != true) {
      return;
    }

    setState(() => _changingPassword = true);
    try {
      await ref.read(customerAccountApiProvider).changePassword(
            ChangeCustomerPasswordRequest(
              currentPassword: _currentPasswordController.text,
              newPassword: _newPasswordController.text,
              confirmNewPassword: _confirmPasswordController.text,
            ),
          );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Password updated.')),
          );
      }
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _changingPassword = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).userSession;
    final profileState = ref.watch(customerProfileProvider);

    profileState.whenData((profile) {
      if (!_profileHydrated) {
        _profileHydrated = true;
        _nameController.text = profile.fullName;
        _phoneController.text = profile.phoneNumber ?? '';
      }
    });

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Account profile',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  profileState.when(
                    data: (profile) => Text(profile.email),
                    error: (error, stackTrace) =>
                        Text(session?.email ?? 'Signed in customer'),
                    loading: () => const LinearProgressIndicator(),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppTextFormField(
                    controller: _nameController,
                    labelText: 'Display name',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    textInputAction: TextInputAction.next,
                    validator: AuthFormValidators.fullName,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextFormField(
                    controller: _phoneController,
                    labelText: 'Phone number',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: AuthFormValidators.phoneNumber,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton.icon(
                    onPressed: _savingProfile ? null : _saveProfile,
                    icon: _savingProfile
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Save changes'),
                  ),
                  if (profileState.hasError) ...[
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(customerProfileProvider),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reload profile'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Form(
              key: _passwordFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Change password',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppTextFormField(
                    controller: _currentPasswordController,
                    labelText: 'Current password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    validator: AuthFormValidators.password,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextFormField(
                    controller: _newPasswordController,
                    labelText: 'New password',
                    prefixIcon: const Icon(Icons.password_rounded),
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      final passwordError = AuthFormValidators.password(
                        value,
                        strong: true,
                      );
                      if (passwordError != null) {
                        return passwordError;
                      }

                      if (value == _currentPasswordController.text) {
                        return 'New password must be different.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextFormField(
                    controller: _confirmPasswordController,
                    labelText: 'Confirm new password',
                    prefixIcon: const Icon(Icons.verified_user_outlined),
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    validator: (value) {
                      if ((value ?? '').isEmpty) {
                        return 'Confirm your new password.';
                      }

                      if (value != _newPasswordController.text) {
                        return 'Passwords do not match.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  OutlinedButton.icon(
                    onPressed: _changingPassword ? null : _changePassword,
                    icon: _changingPassword
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.key_rounded),
                    label: const Text('Update password'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isConfirmed = status == 'Confirmed';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: isConfirmed ? AppColors.successSoft : AppColors.warningSoft,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Text(
        isConfirmed ? 'Confirmed' : status,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.icon,
    required this.title,
    required this.body,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                  ),
                  child: Icon(icon, color: AppColors.danger),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                  ),
                  child: Icon(icon),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
