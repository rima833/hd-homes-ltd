import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Password field with show/hide, autocomplete, and Caps Lock detection.
class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.validator,
    this.onFieldSubmitted,
    this.autofillHints = const [AutofillHints.password],
    this.textInputAction = TextInputAction.done,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final VoidCallback? onFieldSubmitted;
  final Iterable<String>? autofillHints;
  final TextInputAction textInputAction;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _obscure = true;
  bool _capsLockOn = false;
  late final FocusNode _keyboardFocus = FocusNode(
    skipTraversal: true,
    canRequestFocus: false,
  );

  @override
  void dispose() {
    _keyboardFocus.dispose();
    super.dispose();
  }

  void _onKey(KeyEvent event) {
    final locked = HardwareKeyboard.instance.lockModesEnabled.contains(
      KeyboardLockMode.capsLock,
    );
    if (locked != _capsLockOn) {
      setState(() => _capsLockOn = locked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _keyboardFocus,
      onKeyEvent: _onKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: widget.controller,
            obscureText: _obscure,
            autofillHints: widget.autofillHints,
            textInputAction: widget.textInputAction,
            onFieldSubmitted: (_) => widget.onFieldSubmitted?.call(),
            decoration: InputDecoration(
              labelText: widget.label,
              prefixIcon: const Icon(LucideIcons.lock),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                    key: ValueKey(_obscure),
                  ),
                ),
              ),
            ),
            validator: widget.validator,
          ),
          if (_capsLockOn) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Caps Lock is on',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.warning,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
