import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/organization_models.dart';
import 'package:lucide_icons/lucide_icons.dart';

class StaffEmployeeFormResult {
  const StaffEmployeeFormResult({
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.jobTitle,
    this.departmentId,
    this.teamId,
    this.managerId,
    this.branchId,
    this.clearDepartment = false,
    this.clearTeam = false,
    this.clearManager = false,
    this.clearBranch = false,
  });

  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? jobTitle;
  final String? departmentId;
  final String? teamId;
  final String? managerId;
  final String? branchId;
  final bool clearDepartment;
  final bool clearTeam;
  final bool clearManager;
  final bool clearBranch;
}

Future<StaffEmployeeFormResult?> showStaffEmployeeFormDialog({
  required BuildContext context,
  required OrganizationSnapshot snap,
  Employee? employee,
  bool isBusy = false,
}) {
  return showDialog<StaffEmployeeFormResult>(
    context: context,
    builder: (_) => _StaffEmployeeFormDialog(
      snap: snap,
      employee: employee,
      isBusy: isBusy,
    ),
  );
}

class _StaffEmployeeFormDialog extends HookWidget {
  const _StaffEmployeeFormDialog({
    required this.snap,
    this.employee,
    this.isBusy = false,
  });

  final OrganizationSnapshot snap;
  final Employee? employee;
  final bool isBusy;

  bool get isEdit => employee != null;

  @override
  Widget build(BuildContext context) {
    final first = useTextEditingController(
      text: employee?.firstName ??
          (employee == null
              ? ''
              : employee!.displayName.split(RegExp(r'\s+')).first),
    );
    final last = useTextEditingController(
      text: employee?.lastName ??
          (employee == null
              ? ''
              : employee!.displayName.split(RegExp(r'\s+')).skip(1).join(' ')),
    );
    final email = useTextEditingController(text: employee?.email ?? '');
    final phone = useTextEditingController(text: employee?.phone ?? '');
    final title = useTextEditingController(text: employee?.positionTitle ?? '');
    final deptId = useState<String?>(employee?.departmentId);
    final teamId = useState<String?>(employee?.teamId);
    final managerId = useState<String?>(employee?.managerId);
    final branchId = useState<String?>(employee?.branchId);
    final error = useState<String?>(null);

    final teamsForDept = snap.teams
        .where((t) => deptId.value == null || t.departmentId == deptId.value)
        .toList();

    return AlertDialog(
      backgroundColor: const Color(0xFF141820),
      title: Text(
        isEdit ? 'Edit staff' : 'Add staff',
        style: const TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error.value != null) ...[
                Text(error.value!, style: const TextStyle(color: AppColors.error)),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: first,
                decoration: const InputDecoration(labelText: 'First name *'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: last,
                decoration: const InputDecoration(labelText: 'Last name *'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: email,
                decoration: const InputDecoration(labelText: 'Work email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phone,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Job title'),
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
                  for (final d in snap.departments)
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
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                // ignore: deprecated_member_use
                value: managerId.value,
                decoration: const InputDecoration(labelText: 'Reports to'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('None'),
                  ),
                  for (final e in snap.employees.where(
                    (e) => e.id != employee?.id && !e.status.isDeactivated,
                  ))
                    DropdownMenuItem(value: e.id, child: Text(e.displayName)),
                ],
                onChanged: (v) => managerId.value = v,
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
          label: isEdit ? 'Save changes' : 'Create staff',
          isLoading: isBusy,
          icon: isEdit ? LucideIcons.save : LucideIcons.userPlus,
          onPressed: isBusy
              ? null
              : () {
                  final f = first.text.trim();
                  final l = last.text.trim();
                  if (f.isEmpty || l.isEmpty) {
                    error.value = 'First and last name are required.';
                    return;
                  }
                  final mail = email.text.trim();
                  if (mail.isNotEmpty && !mail.contains('@')) {
                    error.value = 'Enter a valid email address.';
                    return;
                  }
                  Navigator.of(context).pop(
                    StaffEmployeeFormResult(
                      firstName: f,
                      lastName: l,
                      email: mail.isEmpty ? null : mail,
                      phone: phone.text.trim().isEmpty
                          ? null
                          : phone.text.trim(),
                      jobTitle: title.text.trim().isEmpty
                          ? null
                          : title.text.trim(),
                      departmentId: deptId.value,
                      teamId: teamId.value,
                      managerId: managerId.value,
                      branchId: branchId.value,
                      clearDepartment: isEdit && deptId.value == null,
                      clearTeam: isEdit && teamId.value == null,
                      clearManager: isEdit && managerId.value == null,
                      clearBranch: isEdit && branchId.value == null,
                    ),
                  );
                },
        ),
      ],
    );
  }
}
