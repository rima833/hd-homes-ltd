import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/verification_models.dart';

/// Six-digit OTP entry with autofocus, paste, and auto-submit.
class OtpCodeInput extends StatefulWidget {
  const OtpCodeInput({
    super.key,
    required this.onCompleted,
    this.length = OtpSecurityPolicy.codeLength,
    this.enabled = true,
  });

  final ValueChanged<String> onCompleted;
  final int length;
  final bool enabled;

  @override
  State<OtpCodeInput> createState() => _OtpCodeInputState();
}

class _OtpCodeInputState extends State<OtpCodeInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _nodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _nodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _onChanged(int index, String value) {
    if (value.length > 1) {
      // Paste support
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < widget.length; i++) {
        _controllers[i].text = i < digits.length ? digits[i] : '';
      }
      final focusIndex = digits.length.clamp(0, widget.length - 1);
      _nodes[focusIndex].requestFocus();
      if (digits.length >= widget.length) {
        widget.onCompleted(_code.substring(0, widget.length));
      }
      return;
    }

    if (value.isNotEmpty && index < widget.length - 1) {
      _nodes[index + 1].requestFocus();
    }
    if (_code.length == widget.length &&
        !_code.contains(RegExp(r'[^0-9]')) &&
        !_controllers.any((c) => c.text.isEmpty)) {
      widget.onCompleted(_code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${widget.length}-digit verification code',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(widget.length, (index) {
          return SizedBox(
            width: 48,
            child: TextField(
              controller: _controllers[index],
              focusNode: _nodes[index],
              enabled: widget.enabled,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 1,
              style: Theme.of(context).textTheme.titleLarge,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.base,
                ),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.inputBorder,
                ),
              ),
              onChanged: (v) => _onChanged(index, v),
              onTap: () {
                _controllers[index].selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _controllers[index].text.length,
                );
              },
              autofillHints:
                  index == 0 ? const [AutofillHints.oneTimeCode] : null,
            ),
          );
        }),
      ),
    );
  }
}
