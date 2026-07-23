import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';
import 'front_desk_components.dart';
import 'staff_components.dart';

class StaffRoleAssignmentScreen extends ConsumerStatefulWidget {
  const StaffRoleAssignmentScreen({
    super.key,
    required this.currentHotelId,
    required this.staffMembers,
    required this.initialStaffMember,
    required this.availableRoles,
  });

  final String currentHotelId;
  final List<HotelStaffMember> staffMembers;
  final HotelStaffMember initialStaffMember;
  final List<String> availableRoles;

  @override
  ConsumerState<StaffRoleAssignmentScreen> createState() =>
      _StaffRoleAssignmentScreenState();
}

class _StaffRoleAssignmentScreenState
    extends ConsumerState<StaffRoleAssignmentScreen> {
  late String _selectedUserId;
  late String _selectedRole;
  String? _initializedUserId;
  Set<String> _selectedHotelIds = {};
  Map<String, HotelStaffMember> _assignmentsByHotel = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedUserId = widget.initialStaffMember.userAccountId;
    _selectedRole =
        widget.availableRoles.contains(widget.initialStaffMember.role)
            ? widget.initialStaffMember.role
            : widget.availableRoles.first;
  }

  HotelStaffMember get _selectedMember {
    for (final member in widget.staffMembers) {
      if (member.userAccountId == _selectedUserId) {
        return member;
      }
    }
    return widget.initialStaffMember;
  }

  void _selectMember(String userId) {
    final member = widget.staffMembers.firstWhere(
      (item) => item.userAccountId == userId,
    );
    setState(() {
      _selectedUserId = userId;
      _selectedRole = widget.availableRoles.contains(member.role)
          ? member.role
          : widget.availableRoles.first;
      _initializedUserId = null;
      _selectedHotelIds = {};
      _assignmentsByHotel = {};
    });
  }

  void _initializeAssignments(
    List<WorkingHotel> hotels,
    Map<String, HotelStaffMember> assignments,
  ) {
    if (_initializedUserId == _selectedUserId) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initializedUserId == _selectedUserId) {
        return;
      }
      final activeHotels = assignments.entries
          .where((entry) => entry.value.isAssignmentActive)
          .map((entry) => entry.key)
          .toSet();
      final currentAssignment = assignments[widget.currentHotelId];
      setState(() {
        _assignmentsByHotel = assignments;
        _selectedHotelIds = activeHotels;
        if (currentAssignment != null &&
            widget.availableRoles.contains(currentAssignment.role)) {
          _selectedRole = currentAssignment.role;
        }
        _initializedUserId = _selectedUserId;
      });
    });
  }

  Future<void> _save(List<WorkingHotel> hotels) async {
    if (_selectedHotelIds.isEmpty) {
      AppErrorPresenter.showSnackBar(
        context,
        'Select at least one hotel for this staff member.',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final api = ref.read(operationsApiProvider);
      for (final hotel in hotels) {
        final assignment = _assignmentsByHotel[hotel.id];
        final selected = _selectedHotelIds.contains(hotel.id);
        if (selected && assignment == null) {
          await api.attachStaff(
            hotelId: hotel.id,
            request: AttachStaffRequest(
              email: _selectedMember.email,
              role: _selectedRole,
            ),
          );
        } else if (selected && assignment != null) {
          if (!assignment.isAssignmentActive ||
              assignment.role != _selectedRole) {
            await api.updateStaffAssignment(
              hotelId: hotel.id,
              assignmentId: assignment.assignmentId,
              request: UpdateStaffAssignmentRequest(
                role: _selectedRole,
                isActive: true,
              ),
            );
          }
        } else if (!selected &&
            assignment != null &&
            assignment.isAssignmentActive) {
          await api.updateStaffAssignment(
            hotelId: hotel.id,
            assignmentId: assignment.assignmentId,
            request: const UpdateStaffAssignmentRequest(isActive: false),
          );
        }
      }

      for (final hotel in hotels) {
        ref.invalidate(hotelStaffProvider(hotel.id));
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(
          context,
          error,
          title: 'Role assignment not saved',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hotelsState = ref.watch(workingHotelsProvider);
    return FrontDeskRouteScaffold(
      title: 'Role Assignment',
      body: hotelsState.when(
        loading: () => const FrontDeskLoadingState(),
        error: (error, stackTrace) => FrontDeskErrorState(
          error: error,
          title: 'Unable to load hotel scope',
          onRetry: () => ref.invalidate(workingHotelsProvider),
        ),
        data: (hotels) {
          final assignments = <String, HotelStaffMember>{};
          Object? assignmentError;
          var assignmentsLoading = false;
          for (final hotel in hotels) {
            final state = ref.watch(hotelStaffProvider(hotel.id));
            if (state.isLoading) {
              assignmentsLoading = true;
            } else if (state.hasError) {
              assignmentError ??= state.error;
            } else {
              for (final member in state.value ?? const []) {
                if (member.userAccountId == _selectedUserId) {
                  assignments[hotel.id] = member;
                  break;
                }
              }
            }
          }

          if (assignmentsLoading) {
            return const FrontDeskLoadingState();
          }
          if (assignmentError != null) {
            return FrontDeskErrorState(
              error: assignmentError,
              title: 'Unable to load staff hotel assignments',
              onRetry: () {
                for (final hotel in hotels) {
                  ref.invalidate(hotelStaffProvider(hotel.id));
                }
              },
            );
          }

          _initializeAssignments(hotels, assignments);
          if (_initializedUserId != _selectedUserId) {
            return const FrontDeskLoadingState();
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const FrontDeskFieldLabel('Staff Member'),
              DropdownButtonFormField<String>(
                key: ValueKey(_selectedUserId),
                initialValue: _selectedUserId,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person_outline),
                ),
                isExpanded: true,
                items: [
                  for (final member in widget.staffMembers)
                    DropdownMenuItem(
                      value: member.userAccountId,
                      child: Text(
                        '${member.fullName} - ${member.email}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null && value != _selectedUserId) {
                          _selectMember(value);
                        }
                      },
              ),
              const SizedBox(height: AppSpacing.lg),
              const FrontDeskFieldLabel('Hotel Scope'),
              FrontDeskPanel(
                child: hotels.isEmpty
                    ? const Text('No manageable hotel is available.')
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: hotels.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 3.1,
                          crossAxisSpacing: AppSpacing.sm,
                          mainAxisSpacing: AppSpacing.xs,
                        ),
                        itemBuilder: (context, index) {
                          final hotel = hotels[index];
                          final selected = _selectedHotelIds.contains(hotel.id);
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: selected,
                            onChanged: _saving
                                ? null
                                : (value) {
                                    setState(() {
                                      if (value == true) {
                                        _selectedHotelIds.add(hotel.id);
                                      } else {
                                        _selectedHotelIds.remove(hotel.id);
                                      }
                                    });
                                  },
                            title: Text(
                              hotel.displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const FrontDeskFieldLabel('Staff Role'),
              DropdownButtonFormField<String>(
                key: ValueKey('role-$_selectedUserId-$_selectedRole'),
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                ),
                items: [
                  for (final role in widget.availableRoles)
                    DropdownMenuItem(
                      value: role,
                      child: Text(staffRoleLabel(role)),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _selectedRole = value);
                        }
                      },
              ),
              const SizedBox(height: AppSpacing.lg),
              StaffPermissionSummary(role: _selectedRole),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      _saving || hotels.isEmpty ? null : () => _save(hotels),
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Assignment'),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          );
        },
      ),
    );
  }
}
