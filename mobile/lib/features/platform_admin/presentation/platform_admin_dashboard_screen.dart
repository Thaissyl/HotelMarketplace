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

  void _refreshCurrent() {
    switch (_selectedSection) {
      case _AdminSection.dashboard:
        ref.invalidate(adminFinanceSummaryProvider);
        return;
      case _AdminSection.approval:
        ref.invalidate(pendingHotelsProvider);
        return;
      case _AdminSection.commission:
        ref.invalidate(adminHotelsProvider);
        return;
      case _AdminSection.reconciliation:
        ref.invalidate(unreconciledPaymentsProvider);
        return;
      case _AdminSection.refunds:
        ref.invalidate(actionableAdminRefundsProvider);
        ref.invalidate(pendingRefundsProvider);
        return;
      case _AdminSection.settlements:
        ref.invalidate(settlementsProvider);
        return;
    }
  }

  void _handleMenuSelection(Object value) {
    if (value is _AdminSection) {
      setState(() => _selectedSection = value);
      return;
    }
    if (value == _AdminMenuAction.account) {
      context.push(AccountSettingsScreen.routePath);
      return;
    }
    if (value == _AdminMenuAction.signOut) {
      ref.read(authControllerProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedSection == _AdminSection.dashboard,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedSection != _AdminSection.dashboard) {
          setState(() => _selectedSection = _AdminSection.dashboard);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(_selectedSection.title),
          actions: [
            if (_selectedSection != _AdminSection.commission)
              IconButton(
                tooltip: 'Refresh',
                onPressed: _refreshCurrent,
                icon: const Icon(Icons.refresh_rounded),
              ),
            PopupMenuButton<Object>(
              tooltip: 'Open admin navigation',
              onSelected: _handleMenuSelection,
              itemBuilder: (context) => [
                for (final section in _AdminSection.values)
                  PopupMenuItem<Object>(
                    value: section,
                    child: ListTile(
                      leading: Icon(section.icon),
                      title: Text(section.menuLabel),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem<Object>(
                  value: _AdminMenuAction.account,
                  child: ListTile(
                    leading: Icon(Icons.manage_accounts_outlined),
                    title: Text('User Profile'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem<Object>(
                  value: _AdminMenuAction.signOut,
                  child: ListTile(
                    leading: Icon(Icons.logout_rounded),
                    title: Text('Sign Out'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(child: _selectedSection.content),
      ),
    );
  }
}

enum _AdminMenuAction { account, signOut }

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
