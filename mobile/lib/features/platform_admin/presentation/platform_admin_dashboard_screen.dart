import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../account/presentation/account_settings_screen.dart';
import '../../auth/application/auth_controller.dart';
import '../application/platform_admin_providers.dart';
import 'platform_admin_workflow_tabs.dart';

class PlatformAdminDashboardScreen extends ConsumerStatefulWidget {
  const PlatformAdminDashboardScreen({super.key});

  static const String routeName = 'platform-admin';
  static const String routePath = '/platform-admin';

  @override
  ConsumerState<PlatformAdminDashboardScreen> createState() =>
      _PlatformAdminDashboardScreenState();
}

class _PlatformAdminDashboardScreenState
    extends ConsumerState<PlatformAdminDashboardScreen> {
  _AdminSection _selectedSection = _AdminSection.dashboard;

  void _refreshAll(WidgetRef ref) {
    ref.invalidate(adminFinanceSummaryProvider);
    ref.invalidate(pendingHotelsProvider);
    ref.invalidate(adminHotelsProvider);
    ref.invalidate(unreconciledPaymentsProvider);
    ref.invalidate(pendingRefundsProvider);
    ref.invalidate(actionableAdminRefundsProvider);
    ref.invalidate(settlementsProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedSection.title),
        leading: _selectedSection == _AdminSection.dashboard
            ? null
            : IconButton(
                tooltip: 'Back to dashboard',
                onPressed: () {
                  setState(() => _selectedSection = _AdminSection.dashboard);
                },
                icon: const Icon(Icons.arrow_back_rounded),
              ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _refreshAll(ref),
            icon: const Icon(Icons.refresh_rounded),
          ),
          PopupMenuButton<_AdminMenuAction>(
            tooltip: 'Admin menu',
            onSelected: (action) {
              switch (action) {
                case _AdminMenuAction.section:
                  break;
                case _AdminMenuAction.account:
                  context.push(AccountSettingsScreen.routePath);
                case _AdminMenuAction.signOut:
                  ref.read(authControllerProvider.notifier).logout();
              }
            },
            itemBuilder: (context) => [
              for (final section in _AdminSection.values)
                PopupMenuItem(
                  value: _AdminMenuAction.section,
                  onTap: () {
                    setState(() => _selectedSection = section);
                  },
                  child: ListTile(
                    leading: Icon(section.icon),
                    title: Text(section.menuLabel),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: _AdminMenuAction.account,
                child: ListTile(
                  leading: Icon(Icons.manage_accounts_outlined),
                  title: Text('Account settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: _AdminMenuAction.signOut,
                child: ListTile(
                  leading: Icon(Icons.logout_rounded),
                  title: Text('Sign out'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(child: _selectedSection.content),
    );
  }
}

enum _AdminMenuAction { section, account, signOut }

enum _AdminSection {
  dashboard,
  approval,
  commission,
  reconciliation,
  refunds,
  settlements;

  String get title => switch (this) {
        dashboard => 'Admin Dashboard',
        approval => 'Hotel Approval',
        commission => 'Commission Management',
        reconciliation => 'Payment Reconciliation',
        refunds => 'Refund Management',
        settlements => 'Settlement Management',
      };

  String get menuLabel => switch (this) {
        dashboard => 'Dashboard',
        approval => 'Hotel approval',
        commission => 'Commission',
        reconciliation => 'Reconciliation',
        refunds => 'Refunds',
        settlements => 'Settlements',
      };

  IconData get icon => switch (this) {
        dashboard => Icons.dashboard_outlined,
        approval => Icons.domain_verification_outlined,
        commission => Icons.percent_rounded,
        reconciliation => Icons.fact_check_outlined,
        refunds => Icons.replay_outlined,
        settlements => Icons.account_balance_outlined,
      };

  Widget get content => switch (this) {
        dashboard => const AdminOverviewTab(),
        approval => const HotelApprovalTab(),
        commission => const CommissionManagementTab(),
        reconciliation => const PaymentReconciliationTab(),
        refunds => const RefundManagementTab(),
        settlements => const SettlementManagementTab(),
      };
}
