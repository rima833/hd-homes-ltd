import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';

class AppTextField extends HookWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.autofillHints,
    this.enabled = true,
    this.maxLines = 1,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final isObscured = useState(obscureText);
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          obscureText: isObscured.value,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          autofillHints: autofillHints,
          enabled: enabled,
          maxLines: maxLines,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            errorText: errorText,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
            suffixIcon: obscureText
                ? IconButton(
                    icon: Icon(
                      isObscured.value
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                    onPressed: () => isObscured.value = !isObscured.value,
                  )
                : suffixIcon,
          ),
        ),
        if (helperText != null && !hasError) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(helperText!, style: Theme.of(context).textTheme.labelSmall),
        ],
      ],
    );
  }
}

/// Search field with icon and rounded styling.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    this.controller,
    this.hint = 'Search properties, estates...',
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(AppIcons.search),
        filled: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.md,
        ),
      ),
    );
  }
}
