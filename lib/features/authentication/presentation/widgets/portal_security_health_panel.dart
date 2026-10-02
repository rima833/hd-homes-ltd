import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/mfa_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/account_security_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/mfa_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/security_health_providers.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/verification_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/mfa_trust_device_controls.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// In-portal Security Health overview — live MFA, sessions, trust, verification.
class PortalSecurityHealthPanel extends ConsumerWidget {
  const PortalSecurityHealthPanel({
    super.key,
    this.embedded = true,
  });

  /// When true, omits outer padding (parent card supplies it).
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(securityHealthProvider);
    final readiness = ref.watch(securityReadinessProvider);
    final verification = ref.watch(verificationSnapshotProvider);
    final mfaAsync = ref.watch(mfaStatusProvider);
    final sessionCount =
        ref.watch(activeSessionCountProvider).valueOrNull ?? 0;
    final mfa = mfaAsync.valueOrNull;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ScoreRing(score: readiness),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Security Health',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    readiness >= 80
                        ? 'Strong protection on this account'
                        : readiness >= 55
                            ? 'Good — a few improvements left'
                            : 'Strengthen your account security',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.slate400,
                        ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: readiness / 100,
                      minHeight: 8,
                      backgroundColor: AppColors.slate700.withValues(alpha: 0.5),
                      color: AppColors.gold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$readiness / 100',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _CheckRow(
          icon: LucideIcons.mail,
          title: 'Email verification',
          ok: verification.emailVerified,
          detail: verification.emailVerified ? 'Verified' : 'Pending',
          actionLabel: 'Manage',
          onAction: () => context.go(RoutePaths.verificationCenter),
        ),
        _CheckRow(
          icon: LucideIcons.smartphone,
          title: 'Phone number',
          ok: verification.phoneVerified,
          detail: verification.phoneVerified
              ? (verification.phone ?? 'On file')
              : 'Not added',
          actionLabel: verification.phoneVerified ? 'Edit' : 'Add',
          onAction: () => context.go(RoutePaths.profileCenter),
        ),
        _CheckRow(
          icon: LucideIcons.shield,
          title: 'Authenticator MFA',
          ok: mfa?.enabled ?? false,
          detail: mfa == null
              ? 'Loading…'
              : mfa.enabled
                  ? 'Enabled · ${mfa.backupCodesRemaining} backup codes'
                  : mfa.needsSetup
                      ? 'Required for your role'
                      : 'Not enabled',
          actionLabel: (mfa?.enabled ?? false) ? 'Manage' : 'Enable',
          onAction: () => context.go(
            (mfa?.enabled ?? false)
                ? RoutePaths.securityCenter
                : RoutePaths.mfaSetup,
          ),
        ),
        _CheckRow(
          icon: LucideIcons.monitorSmartphone,
          title: 'Trusted devices',
          ok: (mfa?.trustedDeviceCount ?? 0) > 0,
          detail: '${mfa?.trustedDeviceCount ?? 0} trusted',
          actionLabel: 'View',
          onAction: () => showTrustedDevicesSheet(context, ref),
        ),
        _CheckRow(
          icon: LucideIcons.laptop,
          title: 'Active sessions',
          ok: sessionCount > 0 && sessionCount <= 5,
          detail: '$sessionCount active',
          actionLabel: 'Review',
          onAction: () => context.go(RoutePaths.activeSessions),
        ),
        if (health.recommendations.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Recommendations',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.slate400,
                ),
          ),
          const SizedBox(height: 8),
          ...health.recommendations.take(3).map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        LucideIcons.sparkles,
                        size: 14,
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          r,
                          style: const TextStyle(
                            color: AppColors.slate400,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go(RoutePaths.securityCenter),
            icon: const Icon(LucideIcons.shield, size: 16),
            label: const Text('Open Security Center'),
          ),
        ),
      ],
    );

    if (embedded) return body;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: body,
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 6,
              backgroundColor: AppColors.slate700.withValues(alpha: 0.45),
              color: AppColors.gold,
            ),
          ),
          Text(
            '$score',
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.icon,
    required this.title,
    required this.ok,
    required this.detail,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final bool ok;
  final String detail;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.success : AppColors.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  detail,
                  style: const TextStyle(
                    color: AppColors.slate400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet: list / revoke / extend trust (14 / 30 / 90).
Future<void> showTrustedDevicesSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final devices =
      await ref.read(mfaServiceProvider).listTrustedDevices();
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.darkSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return _TrustedDevicesSheetBody(initialDevices: devices);
    },
  );
}

class _TrustedDevicesSheetBody extends ConsumerStatefulWidget {
  const _TrustedDevicesSheetBody({required this.initialDevices});

  final List<MfaTrustedDevice> initialDevices;

  @override
  ConsumerState<_TrustedDevicesSheetBody> createState() =>
      _TrustedDevicesSheetBodyState();
}

class _TrustedDevicesSheetBodyState
    extends ConsumerState<_TrustedDevicesSheetBody> {
  late List<MfaTrustedDevice> _devices;
  String? _extendingId;
  int _extendDays = MfaTrustDurationOptions.days30;
  bool _trustingCurrent = false;
  int _trustCurrentDays = MfaTrustDurationOptions.days30;

  @override
  void initState() {
    super.initState();
    _devices = List.of(widget.initialDevices);
  }

  Future<void> _reload() async {
    final list = await ref.read(mfaServiceProvider).listTrustedDevices();
    if (mounted) setState(() => _devices = list);
    ref.invalidate(mfaStatusProvider);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd().add_jm();
    final busy = ref.watch(mfaControllerProvider).isBusy;
    final hasCurrent = _devices.any((d) => d.isCurrent && d.isTrustValid);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Trusted devices',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Devices that can skip MFA for a chosen window.',
                style: TextStyle(color: AppColors.slate400, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_devices.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No trusted devices yet. Trust this device after MFA verify, or below.',
                    style: TextStyle(color: AppColors.slate400),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ..._devices.map((d) {
                  final extending = _extendingId == d.id;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.18),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d.isCurrent
                                        ? 'This device'
                                        : (d.deviceName ?? 'Device'),
                                    style: const TextStyle(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      if (d.browser != null) d.browser,
                                      if (d.operatingSystem != null)
                                        d.operatingSystem,
                                      if (d.trustedUntil != null)
                                        'Until ${fmt.format(d.trustedUntil!.toLocal())}',
                                      if (!d.isTrustValid) 'Expired',
                                    ].whereType<String>().join(' · '),
                                    style: const TextStyle(
                                      color: AppColors.slate400,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Revoke',
                              icon: const Icon(
                                LucideIcons.trash2,
                                size: 18,
                                color: AppColors.error,
                              ),
                              onPressed: busy
                                  ? null
                                  : () async {
                                      await ref
                                          .read(mfaServiceProvider)
                                          .revokeTrustedDevice(d.id);
                                      await _reload();
                                    },
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => setState(() {
                              _extendingId = extending ? null : d.id;
                              _extendDays = MfaTrustDurationOptions.days30;
                            }),
                            child: Text(extending ? 'Cancel' : 'Extend trust'),
                          ),
                        ),
                        if (extending) ...[
                          MfaTrustDeviceControls(
                            enabled: true,
                            showSwitch: false,
                            selectedDays: _extendDays,
                            busy: busy,
                            onEnabledChanged: (_) {},
                            onDaysChanged: (days) =>
                                setState(() => _extendDays = days),
                          ),
                          const SizedBox(height: 8),
                          PrimaryButton(
                            label: 'Save ${MfaTrustDurationOptions.label(_extendDays)}',
                            expand: true,
                            isLoading: busy,
                            onPressed: busy
                                ? null
                                : () async {
                                    await ref
                                        .read(mfaControllerProvider.notifier)
                                        .extendDeviceTrust(
                                          deviceId: d.id,
                                          durationDays: _extendDays,
                                        );
                                    if (mounted) {
                                      setState(() => _extendingId = null);
                                      await _reload();
                                    }
                                  },
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              if (!hasCurrent) ...[
                const Divider(height: 28),
                Text(
                  'Trust this device',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.white,
                      ),
                ),
                const SizedBox(height: 8),
                if (!_trustingCurrent)
                  OutlinedButton(
                    onPressed: () => setState(() => _trustingCurrent = true),
                    child: const Text('Trust this device now'),
                  )
                else ...[
                  MfaTrustDeviceControls(
                    enabled: true,
                    showSwitch: false,
                    selectedDays: _trustCurrentDays,
                    busy: busy,
                    onEnabledChanged: (_) {},
                    onDaysChanged: (d) =>
                        setState(() => _trustCurrentDays = d),
                  ),
                  const SizedBox(height: 8),
                  PrimaryButton(
                    label:
                        'Trust for ${MfaTrustDurationOptions.label(_trustCurrentDays)}',
                    expand: true,
                    isLoading: busy,
                    onPressed: busy
                        ? null
                        : () async {
                            await ref
                                .read(mfaControllerProvider.notifier)
                                .trustThisDevice(
                                  durationDays: _trustCurrentDays,
                                );
                            if (mounted) {
                              setState(() => _trustingCurrent = false);
                              await _reload();
                            }
                          },
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
