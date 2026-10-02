import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Client / investor portal card to submit a testimonial for admin review.
class PortalShareTestimonialCard extends ConsumerStatefulWidget {
  const PortalShareTestimonialCard({
    super.key,
    this.defaultRoleHint,
  });

  /// Suggested title under the name (e.g. "HD Homes investor").
  final String? defaultRoleHint;

  @override
  ConsumerState<PortalShareTestimonialCard> createState() =>
      _PortalShareTestimonialCardState();
}

class _PortalShareTestimonialCardState
    extends ConsumerState<PortalShareTestimonialCard> {
  final _quote = TextEditingController();
  final _title = TextEditingController();
  int _rating = 5;
  bool _submitting = false;
  String? _message;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _title.text = widget.defaultRoleHint ?? '';
  }

  @override
  void dispose() {
    _quote.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final session = ref.read(identitySessionProvider);
    final profile = session.profile;
    final name = [
      profile?.firstName,
      profile?.lastName,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ').trim();
    final displayName = name.isNotEmpty
        ? name
        : (profile?.email.split('@').first ?? 'HD Homes client');

    setState(() {
      _submitting = true;
      _message = null;
      _success = false;
    });
    try {
      await ref.read(cmsServiceProvider).submitPortalTestimonial(
            clientName: displayName,
            clientTitle: _title.text.trim().isEmpty
                ? widget.defaultRoleHint
                : _title.text.trim(),
            content: _quote.text.trim(),
            rating: _rating,
          );
      if (!mounted) return;
      setState(() {
        _success = true;
        _message =
            'Thanks — your story was sent for review. Once approved it appears on Home and Opportunities.';
        _quote.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _success = false;
        _message = e is AppException ? e.message : userFacingError(e);
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.quote, color: AppColors.gold, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Share your experience',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your quote is reviewed by HD Homes before it appears on the website (Home + Opportunities).',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.slate400,
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'How should we introduce you?',
              hintText: 'e.g. Investor · Lagos',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _quote,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Your experience',
              hintText: 'What stood out about working with HD Homes?',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Rating',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.slate400,
                    ),
              ),
              const SizedBox(width: 12),
              for (var i = 1; i <= 5; i++)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _rating = i),
                  icon: Icon(
                    LucideIcons.star,
                    size: 18,
                    color: i <= _rating ? AppColors.gold : AppColors.slate500,
                  ),
                ),
            ],
          ),
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(
              _message!,
              style: TextStyle(
                color: _success ? AppColors.success : AppColors.error,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.send, size: 16),
              label: Text(_submitting ? 'Sending…' : 'Submit for review'),
            ),
          ),
        ],
      ),
    );
  }
}
