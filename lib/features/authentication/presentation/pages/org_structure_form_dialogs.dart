import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/organization_models.dart';
import 'package:lucide_icons/lucide_icons.dart';

class DepartmentFormResult {
  const DepartmentFormResult({
    required this.name,
    this.description,
    this.headEmployeeId,
    this.status,
    this.clearHead = false,
  });

  final String name;
  final String? description;
  final String? headEmployeeId;
  final OrgEntityStatus? status;
  final bool clearHead;
}

class TeamFormResult {
  const TeamFormResult({
    required this.name,
    required this.departmentId,
    this.description,
    this.teamLeadId,
    this.branchId,
    this.status,
    this.clearLead = false,
    this.clearBranch = false,
  });

  final String name;
  final String departmentId;
  final String? description;
  final String? teamLeadId;
  final String? branchId;
  final OrgEntityStatus? status;
  final bool clearLead;
  final bool clearBranch;
}

class ReassignStaffResult {
  const ReassignStaffResult({
    required this.employeeId,
    this.departmentId,
    this.teamId,
    this.clearDepartment = false,
    this.clearTeam = false,
  });

  final String employeeId;
  final String? departmentId;
  final String? teamId;
  final bool clearDepartment;
  final bool clearTeam;
}

Future<DepartmentFormResult?> showDepartmentFormDialog({
  required BuildContext context,
  required OrganizationSnapshot snap,
  Department? department,
  bool isBusy = false,
}) {
  return showDialog<DepartmentFormResult>(
    context: context,
    builder: (_) => _DepartmentFormDialog(
      snap: snap,
      department: department,
      isBusy: isBusy,
    ),
  );
}

Future<TeamFormResult?> showTeamFormDialog({
  required BuildContext context,
  required OrganizationSnapshot snap,
  OrgTeam? team,
  String? preferredDepartmentId,
  bool isBusy = false,
}) {
  return showDialog<TeamFormResult>(
    context: context,
    builder: (_) => _TeamFormDialog(
      snap: snap,
      team: team,
      preferredDepartmentId: preferredDepartmentId,
      isBusy: isBusy,
    ),
  );
}

Future<ReassignStaffResult?> showReassignStaffDialog({
  required BuildContext context,
  required OrganizationSnapshot snap,
  String? preferredDepartmentId,
  String? preferredTeamId,
  bool isBusy = false,
}) {
  return showDialog<ReassignStaffResult>(
    context: context,
    builder: (_) => _ReassignStaffDialog(
      snap: snap,
      preferredDepartmentId: preferredDepartmentId,
      preferredTeamId: preferredTeamId,
      isBusy: isBusy,
    ),
  );
}

class _DepartmentFormDialog extends HookWidget {
  const _DepartmentFormDialog({
    required this.snap,
    this.department,
    this.isBusy = false,
  });

  final OrganizationSnapshot snap;
  final Department? department;
  final bool isBusy;

  bool get isEdit => department != null;

  @override
  Widget build(BuildContext context) {
    final name = useTextEditingController(text: department?.name ?? '');
    final description =
        useTextEditingController(text: department?.description ?? '');
    final headId = useState<String?>(department?.headEmployeeId);
    final status = useState<OrgEntityStatus>(
      department?.status ?? OrgEntityStatus.active,
    );
    final error = useState<String?>(null);

    return AlertDialog(
      backgroundColor: const Color(0xFF141820),
      title: Text(
        isEdit ? 'Edit department' : 'Add department',
        style: const TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error.value != null) ...[
                Text(error.value!, style: const TextStyle(color: AppColors.error)),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: description,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                // ignore: deprecated_member_use
                value: headId.value,
                decoration: const InputDecoration(labelText: 'Department head'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Unassigned'),
                  ),
                  for (final e in snap.employees.where(
                    (e) => !e.status.isDeactivated,
                  ))
                    DropdownMenuItem(value: e.id, child: Text(e.displayName)),
                ],
                onChanged: (v) => headId.value = v,
              ),
              if (isEdit) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<OrgEntityStatus>(
                  // ignore: deprecated_member_use
                  value: status.value,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(
                      value: OrgEntityStatus.active,
                      child: Text('Active'),
                    ),
                    DropdownMenuItem(
                      value: OrgEntityStatus.inactive,
                      child: Text('Inactive'),
                    ),
                    DropdownMenuItem(
                      value: OrgEntityStatus.archived,
                      child: Text('Archived'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) status.value = v;
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isBusy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        PrimaryButton(
          label: isEdit ? 'Save' : 'Create',
          isLoading: isBusy,
          icon: isEdit ? LucideIcons.save : LucideIcons.building,
          onPressed: isBusy
              ? null
              : () {
                  final n = name.text.trim();
                  if (n.isEmpty) {
                    error.value = 'Name is required.';
                    return;
                  }
                  Navigator.of(context).pop(
                    DepartmentFormResult(
                      name: n,
                      description: description.text.trim().isEmpty
                          ? null
                          : description.text.trim(),
                      headEmployeeId: headId.value,
                      status: isEdit ? status.value : null,
                      clearHead: isEdit && headId.value == null,
                    ),
                  );
                },
        ),
      ],
    );
  }
}

class _TeamFormDialog extends HookWidget {
  const _TeamFormDialog({
    required this.snap,
    this.team,
    this.preferredDepartmentId,
    this.isBusy = false,
  });

  final OrganizationSnapshot snap;
  final OrgTeam? team;
  final String? preferredDepartmentId;
  final bool isBusy;

  bool get isEdit => team != null;

  @override
  Widget build(BuildContext context) {
    final name = useTextEditingController(text: team?.name ?? '');
    final description =
        useTextEditingController(text: team?.description ?? '');
    final deptId = useState<String?>(
      team?.departmentId ??
          preferredDepartmentId ??
          (snap.departments.isEmpty ? null : snap.departments.first.id),
    );
    final leadId = useState<String?>(team?.teamLeadId);
    final branchId = useState<String?>(team?.branchId);
    final status = useState<OrgEntityStatus>(
      team?.status ?? OrgEntityStatus.active,
    );
    final error = useState<String?>(null);

    return AlertDialog(
      backgroundColor: const Color(0xFF141820),
      title: Text(
        isEdit ? 'Edit team' : 'Add team',
        style: const TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error.value != null) ...[
                Text(error.value!, style: const TextStyle(color: AppColors.error)),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name *'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: deptId.value,
                decoration: const InputDecoration(labelText: 'Department *'),
                items: [
                  for (final d in snap.departments.where(
                    (d) => d.status == OrgEntityStatus.active,
                  ))
                    DropdownMenuItem(value: d.id, child: Text(d.name)),
                ],
                onChanged: (v) => deptId.value = v,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: description,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                // ignore: deprecated_member_use
                value: leadId.value,
                decoration: const InputDecoration(labelText: 'Team lead'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Unassigned'),
                  ),
                  for (final e in snap.employees.where((e) {
                    if (e.status.isDeactivated) return false;
                    if (deptId.value == null) return true;
                    return e.departmentId == deptId.value;
                  }))
                    DropdownMenuItem(value: e.id, child: Text(e.displayName)),
                ],
                onChanged: (v) => leadId.value = v,
              ),
              if (snap.branches.isNotEmpty) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  // ignore: deprecated_member_use
                  value: branchId.value,
                  decoration: const InputDecoration(labelText: 'Branch'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Unassigned'),
                    ),
                    for (final b in snap.branches)
                      DropdownMenuItem(value: b.id, child: Text(b.name)),
                  ],
                  onChanged: (v) => branchId.value = v,
                ),
              ],
              if (isEdit) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<OrgEntityStatus>(
                  // ignore: deprecated_member_use
                  value: status.value,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(
                      value: OrgEntityStatus.active,
                      child: Text('Active'),
                    ),
                    DropdownMenuItem(
                      value: OrgEntityStatus.inactive,
                      child: Text('Inactive'),
                    ),
                    DropdownMenuItem(
                      value: OrgEntityStatus.archived,
                      child: Text('Archived'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) status.value = v;
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isBusy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        PrimaryButton(
          label: isEdit ? 'Save' : 'Create',
          isLoading: isBusy,
          icon: isEdit ? LucideIcons.save : LucideIcons.users,
          onPressed: isBusy
              ? null
              : () {
                  final n = name.text.trim();
                  final d = deptId.value;
                  if (n.isEmpty || d == null) {
                    error.value = 'Name and department are required.';
                    return;
                  }
                  Navigator.of(context).pop(
                    TeamFormResult(
                      name: n,
                      departmentId: d,
                      description: description.text.trim().isEmpty
                          ? null
                          : description.text.trim(),
                      teamLeadId: leadId.value,
                      branchId: branchId.value,
                      status: isEdit ? status.value : null,
                      clearLead: isEdit && leadId.value == null,
                      clearBranch: isEdit && branchId.value == null,
                    ),
                  );
                },
        ),
      ],
    );
  }
}

class _ReassignStaffDialog extends HookWidget {
  const _ReassignStaffDialog({
    required this.snap,
    this.preferredDepartmentId,
    this.preferredTeamId,
    this.isBusy = false,
  });

  final OrganizationSnapshot snap;
  final String? preferredDepartmentId;
  final String? preferredTeamId;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final employeeId = useState<String?>(null);
    final deptId = useState<String?>(preferredDepartmentId);
    final teamId = useState<String?>(preferredTeamId);
    final error = useState<String?>(null);

    final teamsForDept = snap.teams.where((t) {
      if (t.status != OrgEntityStatus.active) return false;
      if (deptId.value == null) return true;
      return t.departmentId == deptId.value;
    }).toList();

    return AlertDialog(
      backgroundColor: const Color(0xFF141820),
      title: const Text(
        'Assign staff',
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error.value != null) ...[
              Text(error.value!, style: const TextStyle(color: AppColors.error)),
              const SizedBox(height: 8),
            ],
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: employeeId.value,
              decoration: const InputDecoration(labelText: 'Staff member *'),
              items: [
                for (final e in snap.employees.where(
                  (e) => !e.status.isDeactivated,
                ))
                  DropdownMenuItem(
                    value: e.id,
                    child: Text(
                      '${e.displayName} · ${e.departmentName ?? 'Unassigned'}',
                    ),
                  ),
              ],
              onChanged: (v) => employeeId.value = v,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              // ignore: deprecated_member_use
              value: deptId.value,
              decoration: const InputDecoration(labelText: 'Department'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Unassigned'),
                ),
                for (final d in snap.departments.where(
                  (d) => d.status == OrgEntityStatus.active,
                ))
                  DropdownMenuItem(value: d.id, child: Text(d.name)),
              ],
              onChanged: (v) {
                deptId.value = v;
                if (teamId.value != null &&
                    !teamsForDept.any((t) => t.id == teamId.value)) {
                  teamId.value = null;
                }
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              // ignore: deprecated_member_use
              value: teamId.value,
              decoration: const InputDecoration(labelText: 'Team'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Unassigned'),
                ),
                for (final t in teamsForDept)
                  DropdownMenuItem(value: t.id, child: Text(t.name)),
              ],
              onChanged: (v) => teamId.value = v,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isBusy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        PrimaryButton(
          label: 'Assign',
          isLoading: isBusy,
          icon: LucideIcons.userCog,
          onPressed: isBusy
              ? null
              : () {
                  final id = employeeId.value;
                  if (id == null) {
                    error.value = 'Select a staff member.';
                    return;
                  }
                  Navigator.of(context).pop(
                    ReassignStaffResult(
                      employeeId: id,
                      departmentId: deptId.value,
                      teamId: teamId.value,
                      clearDepartment: deptId.value == null,
                      clearTeam: teamId.value == null,
                    ),
                  );
                },
        ),
      ],
    );
  }
}
