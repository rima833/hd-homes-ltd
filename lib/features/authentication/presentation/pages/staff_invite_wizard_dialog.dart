import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/organization_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/organization_service.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Result of the multi-step Add Staff → Send Invitation wizard.
class StaffInviteWizardResult {
  const StaffInviteWizardResult({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.roleSlug,
    this.phone,
    this.departmentId,
    this.teamId,
    this.jobTitle,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String? departmentId;
  final String? teamId;
  final String? jobTitle;
  final String roleSlug;
}

/// Polished multi-step staff invitation dialog (master Add Staff flow).
Future<StaffInviteWizardResult?> showStaffInviteWizard({
  required BuildContext context,
  required OrganizationSnapshot snap,
  required List<(String, String)> roleOptions,
  bool isBusy = false,
}) {
  if (roleOptions.isEmpty) return Future.value(null);
  return showDialog<StaffInviteWizardResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _StaffInviteWizardDialog(
      snap: snap,
      roleOptions: roleOptions,
      isBusy: isBusy,
    ),
  );
}

class _StaffInviteWizardDialog extends HookWidget {
  const _StaffInviteWizardDialog({
    required this.snap,
    required this.roleOptions,
    this.isBusy = false,
  });

  final OrganizationSnapshot snap;
  final List<(String, String)> roleOptions;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final step = useState(0);
    final first = useTextEditingController();
    final last = useTextEditingController();
    final email = useTextEditingController();
    final phone = useTextEditingController();
    final jobTitle = useTextEditingController();
    final departments = snap.departments
        .where((d) => OrganizationService.isValidUuid(d.id))
        .toList();
    final deptId = useState<String?>(
      departments.isEmpty ? null : departments.first.id,
    );
    final teamId = useState<String?>(null);
    final roleSlug = useState(roleOptions.first.$1);
    final error = useState<String?>(null);

    final teamsForDept = snap.teams
        .where((t) => deptId.value == null || t.departmentId == deptId.value)
        .toList();

    String? validateStep(int s) {
      if (s == 0) {
        if (first.text.trim().isEmpty) return 'First name is required.';
        if (last.text.trim().isEmpty) return 'Last name is required.';
        final em = email.text.trim();
        if (em.isEmpty || !em.contains('@')) {
          return 'Enter a valid work email address.';
        }
      }
      if (s == 2 && roleSlug.value.trim().isEmpty) {
        return 'Select a role.';
      }
      return null;
    }

    void next() {
      final err = validateStep(step.value);
      if (err != null) {
        error.value = err;
        return;
      }
      error.value = null;
      if (step.value < 3) step.value = step.value + 1;
    }

    void back() {
      error.value = null;
      if (step.value > 0) step.value = step.value - 1;
    }

    final deptName = departments
        .where((d) => d.id == deptId.value)
        .map((d) => d.name)
        .firstOrNull;
    final teamName = teamsForDept
        .where((t) => t.id == teamId.value)
        .map((t) => t.name)
        .firstOrNull;
    final roleLabel = roleOptions
        .where((r) => r.$1 == roleSlug.value)
        .map((r) => r.$2)
        .firstOrNull;

    final width = MediaQuery.sizeOf(context).width;
    final dialogWidth = width < 560 ? width - 32.0 : 520.0;

    return AlertDialog(
      backgroundColor: const Color(0xFF141820),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Staff',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            switch (step.value) {
              0 => 'Step 1 · Basic information',
              1 => 'Step 2 · Organization',
              2 => 'Step 3 · Access',
              _ => 'Step 4 · Review & invite',
            },
            style: const TextStyle(
              color: Color(0xFF8B929E),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < 4; i++)
                Expanded(
                  child: Container(
                    height: 3,
                    margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                    decoration: BoxDecoration(
                      color: i <= step.value
                          ? AppColors.gold
                          : const Color(0x22FFFFFF),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error.value != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    error.value!,
                    style: const TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (step.value == 0) ...[
                _field(first, 'First name', LucideIcons.user),
                const SizedBox(height: 10),
                _field(last, 'Last name', LucideIcons.user),
                const SizedBox(height: 10),
                _field(email, 'Work email', LucideIcons.mail,
                    keyboard: TextInputType.emailAddress),
                const SizedBox(height: 10),
                _field(phone, 'Phone (optional)', LucideIcons.phone,
                    keyboard: TextInputType.phone),
              ] else if (step.value == 1) ...[
                _dropdown<String>(
                  label: 'Department',
                  value: deptId.value,
                  items: [
                    for (final d in departments)
                      DropdownMenuItem(value: d.id, child: Text(d.name)),
                  ],
                  onChanged: (v) {
                    deptId.value = v;
                    teamId.value = null;
                  },
                ),
                const SizedBox(height: 10),
                _dropdown<String>(
                  label: 'Team',
                  value: teamId.value,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('No team'),
                    ),
                    for (final t in teamsForDept)
                      DropdownMenuItem(value: t.id, child: Text(t.name)),
                  ],
                  onChanged: (v) => teamId.value = v,
                ),
                const SizedBox(height: 10),
                _field(jobTitle, 'Job title (optional)', LucideIcons.briefcase),
              ] else if (step.value == 2) ...[
                _dropdown<String>(
                  label: 'Role',
                  value: roleSlug.value,
                  items: [
                    for (final r in roleOptions)
                      DropdownMenuItem(value: r.$1, child: Text(r.$2)),
                  ],
                  onChanged: (v) {
                    if (v != null) roleSlug.value = v;
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B0E14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x22FFFFFF)),
                  ),
                  child: const Text(
                    'Permissions follow the existing HD Homes Roles & Permissions matrix. The invitee cannot elevate their own role.',
                    style: TextStyle(color: Color(0xFF8B929E), fontSize: 12),
                  ),
                ),
              ] else ...[
                _reviewRow('Name', '${first.text.trim()} ${last.text.trim()}'),
                _reviewRow('Email', email.text.trim()),
                if (phone.text.trim().isNotEmpty)
                  _reviewRow('Phone', phone.text.trim()),
                _reviewRow('Department', deptName ?? '—'),
                _reviewRow('Team', teamName ?? '—'),
                if (jobTitle.text.trim().isNotEmpty)
                  _reviewRow('Job title', jobTitle.text.trim()),
                _reviewRow('Role', roleLabel ?? roleSlug.value),
                const SizedBox(height: 8),
                const Text(
                  'An HD Homes branded invitation email will be queued and the directory will update in realtime.',
                  style: TextStyle(color: Color(0xFF8B929E), fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isBusy
              ? null
              : () {
                  if (step.value == 0) {
                    Navigator.of(context).pop();
                  } else {
                    back();
                  }
                },
          child: Text(step.value == 0 ? 'Cancel' : 'Back'),
        ),
        if (step.value < 3)
          PrimaryButton(
            label: 'Continue',
            onPressed: isBusy ? null : next,
          )
        else
          PrimaryButton(
            label: isBusy ? 'Sending…' : 'Send Invitation',
            icon: LucideIcons.send,
            onPressed: isBusy
                ? null
                : () {
                    final err = validateStep(0);
                    if (err != null) {
                      error.value = err;
                      step.value = 0;
                      return;
                    }
                    Navigator.of(context).pop(
                      StaffInviteWizardResult(
                        firstName: first.text.trim(),
                        lastName: last.text.trim(),
                        email: email.text.trim(),
                        phone: phone.text.trim().isEmpty
                            ? null
                            : phone.text.trim(),
                        departmentId: deptId.value,
                        teamId: teamId.value,
                        jobTitle: jobTitle.text.trim().isEmpty
                            ? null
                            : jobTitle.text.trim(),
                        roleSlug: roleSlug.value,
                      ),
                    );
                  },
          ),
      ],
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF8B929E)),
        labelStyle: const TextStyle(color: Color(0xFF8B929E)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0x22FFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.gold),
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF8B929E)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0x22FFFFFF)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF1A1F2A),
          style: const TextStyle(color: Colors.white),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF8B929E), fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
