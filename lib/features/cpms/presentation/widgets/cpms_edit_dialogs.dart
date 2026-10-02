import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cpms/domain/entities/cpms_models.dart';
import 'package:hdhomesproject/features/cpms/presentation/widgets/cpms_command_center_shell.dart';

Future<T?> showCpmsFormDialog<T>({
  required BuildContext context,
  required String title,
  required List<Widget> fields,
  String confirmLabel = 'Save',
}) {
  return showDialog<T>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: CpmsDeskColors.elevated,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: fields,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true as T),
          style: FilledButton.styleFrom(
            backgroundColor: CpmsDeskColors.gold,
            foregroundColor: const Color(0xFF1A1205),
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

Widget cpmsField({
  required TextEditingController controller,
  required String label,
  int maxLines = 1,
  TextInputType? keyboardType,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: CpmsDeskColors.muted),
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
      ),
    ),
  );
}

Widget cpmsDropdown<T>({
  required String label,
  required T value,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?> onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      dropdownColor: CpmsDeskColors.elevated,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: CpmsDeskColors.muted),
        border: const OutlineInputBorder(),
      ),
    ),
  );
}

Future<bool> confirmCpmsDelete(BuildContext context, String label) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: CpmsDeskColors.elevated,
      title: const Text('Delete'),
      content: Text('Delete $label? This cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return ok == true;
}

List<DropdownMenuItem<String>> statusItems(List<String> values) => [
      for (final v in values)
        DropdownMenuItem(value: v, child: Text(v.replaceAll('_', ' '))),
    ];

List<DropdownMenuItem<String>> projectItems(List<CpmsProject> projects) => [
      for (final p in projects)
        DropdownMenuItem(value: p.id, child: Text(p.name)),
    ];
