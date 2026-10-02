import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/theme/theme_provider.dart';
import 'package:hdhomesproject/core/widgets/offline_updates_note.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/portal_share_testimonial_card.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/profile_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/mfa_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/profile_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/verification_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/portal_security_health_panel.dart';
import 'package:hdhomesproject/features/investor/domain/entities/investor_models.dart';
import 'package:hdhomesproject/features/investor/presentation/providers/investor_portal_realtime_provider.dart';
import 'package:hdhomesproject/features/investor/presentation/providers/investor_providers.dart';
import 'package:hdhomesproject/features/investor/presentation/widgets/investor_portal_widgets.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

class InvestorSettingsPage extends ConsumerStatefulWidget {
  const InvestorSettingsPage({super.key});

  @override
  ConsumerState<InvestorSettingsPage> createState() =>
      _InvestorSettingsPageState();
}

class _InvestorSettingsPageState extends ConsumerState<InvestorSettingsPage> {
  bool _emailNotifications = true;
  bool _smsNotifications = true;
  bool _pushNotifications = true;
  bool _distributionAlerts = true;
  bool _performanceAlerts = true;
  bool _constructionAlerts = true;
  String _language = 'en';
  ThemeMode _themeMode = ThemeMode.system;
  bool _loaded = false;
  bool _saving = false;
  bool _savingProfile = false;
  Object? _loadError;
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _phoneCtrl;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController();
    _lastNameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPreferences());
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _syncProfileFields() {
    final p = ref.read(identitySessionProvider).profile;
    if (p == null) return;
    if (_firstNameCtrl.text != (p.firstName ?? '')) {
      _firstNameCtrl.text = p.firstName ?? '';
    }
    if (_lastNameCtrl.text != (p.lastName ?? '')) {
      _lastNameCtrl.text = p.lastName ?? '';
    }
    if (_phoneCtrl.text != (p.phone ?? '')) {
      _phoneCtrl.text = p.phone ?? '';
    }
  }

  Future<void> _saveProfileEssentials() async {
    final profile = ref.read(identitySessionProvider).profile;
    if (profile == null) return;
    setState(() => _savingProfile = true);
    try {
      final hub = await ref.read(profileHubProvider.future);
      final base = hub?.profile ??
          ProfileDetails(id: profile.id, email: profile.email);
      final details = base.copyWith(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      );
      final ok =
          await ref.read(profileControllerProvider.notifier).savePersonal(details);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Profile updated' : 'Could not update profile'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _exportMyData() async {
    final session = ref.read(identitySessionProvider);
    final profile = session.profile;
    final investor = ref.read(investorRecordProvider).valueOrNull;
    final mfa = ref.read(mfaStatusProvider).valueOrNull;
    final verification = ref.read(verificationSnapshotProvider);

    final payload = {
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'portal': 'investor',
      'profile': {
        'id': profile?.id,
        'email': profile?.email ?? session.email,
        'first_name': profile?.firstName,
        'last_name': profile?.lastName,
        'phone': profile?.phone,
      },
      'investor_code': investor?.investorCode,
      'kyc_status': investor?.kycStatus,
      'verification': {
        'email_verified': verification.emailVerified,
        'phone_verified': verification.phoneVerified,
      },
      'mfa_enabled': mfa?.enabled ?? false,
      'preferences': {
        'email_notifications': _emailNotifications,
        'sms_notifications': _smsNotifications,
        'push_notifications': _pushNotifications,
        'distribution_alerts': _distributionAlerts,
        'performance_alerts': _performanceAlerts,
        'construction_alerts': _constructionAlerts,
        'language': _language,
      },
    };

    final json = const JsonEncoder.withIndent('  ').convert(payload);
    await Clipboard.setData(ClipboardData(text: json));
    try {
      await Share.share(json, subject: 'HD Homes — investor data export');
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your data was copied and shared from this device.'),
      ),
    );
  }

  EdgeInsets _padding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return EdgeInsets.all(w >= AppBreakpoints.tablet ? 24 : 16);
  }

  Future<void> _loadPreferences() async {
    try {
      final record = await ref.read(investorRecordProvider.future);
      if (record == null || !mounted) {
        setState(() {
          _loaded = true;
          _loadError = null;
        });
        return;
      }
      final prefs =
          await ref.read(investorServiceProvider).loadPreferences(record.id);
      if (!mounted) return;
      setState(() {
        _emailNotifications = prefs['email_notifications'] as bool? ?? true;
        _smsNotifications = prefs['sms_notifications'] as bool? ?? true;
        _pushNotifications = prefs['push_notifications'] as bool? ?? true;
        _distributionAlerts = prefs['distribution_alerts'] as bool? ?? true;
        _performanceAlerts = prefs['performance_alerts'] as bool? ?? true;
        _constructionAlerts = prefs['construction_alerts'] as bool? ?? true;
        _language = prefs['language'] as String? ?? 'en';
        final theme = prefs['theme'] as String? ?? 'system';
        _themeMode = switch (theme) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        };
        _loaded = true;
        _loadError = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loaded = true;
          _loadError = e;
        });
      }
    }
  }

  Future<void> _savePreferences() async {
    final record = await ref.read(investorRecordProvider.future);
    if (record == null) {
      if (mounted) {
        showFriendlyError(
          context,
          null,
          fallback: 'Investor account not found.',
        );
      }
      return;
    }
    setState(() => _saving = true);
    try {
      final theme = switch (_themeMode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await ref.read(investorServiceProvider).savePreferences(record.id, {
        'email_notifications': _emailNotifications,
        'sms_notifications': _smsNotifications,
        'push_notifications': _pushNotifications,
        'distribution_alerts': _distributionAlerts,
        'performance_alerts': _performanceAlerts,
        'construction_alerts': _constructionAlerts,
        'language': _language,
        'theme': theme,
      });
      await ref.read(themeModeProvider.notifier).setThemeMode(_themeMode);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferences saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        showFriendlyError(
          context,
          e,
          fallback: 'Could not save preferences.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(identitySessionProvider);
    final profile = session.profile;
    final investorAsync = ref.watch(investorRecordProvider);
    final verification = ref.watch(verificationSnapshotProvider);
    final mfaAsync = ref.watch(mfaStatusProvider);
    final mfaOn = mfaAsync.valueOrNull?.enabled ?? false;
    final pad = _padding(context);

    if (!_loaded) {
      return const InvestorPageSkeleton(showKpis: false, rows: 4);
    }

    if (_loadError != null) {
      return InvestorErrorView(
        message: _loadError!,
        onRetry: () {
          setState(() {
            _loaded = false;
            _loadError = null;
          });
          _loadPreferences();
        },
      );
    }

    final displayName = [
      profile?.firstName,
      profile?.lastName,
    ].whereType<String>().join(' ').trim();
    final initial = () {
      final fn = profile?.firstName;
      final em = profile?.email;
      if (fn != null && fn.isNotEmpty) return fn[0].toUpperCase();
      if (em != null && em.isNotEmpty) return em[0].toUpperCase();
      return 'I';
    }();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncProfileFields();
    });

    return ListView(
      padding: pad,
      children: [
        Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Profile, security, and notification preferences for your investor account.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.slate400,
              ),
        ),
        const SizedBox(height: 20),
        const InvestorSectionHeader(title: 'Profile'),
        InvestorPortalCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                      backgroundImage: profile?.avatarUrl != null &&
                              profile!.avatarUrl!.isNotEmpty
                          ? NetworkImage(profile.avatarUrl!)
                          : null,
                      child: profile?.avatarUrl == null ||
                              profile!.avatarUrl!.isEmpty
                          ? Text(
                              initial,
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName.isEmpty ? 'Investor' : displayName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          investorAsync.when(
                            data: (inv) => Text(
                              inv?.investorCode ?? profile?.email ?? '—',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.gold),
                            ),
                            loading: () => Text(
                              profile?.email ?? '—',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.slate400),
                            ),
                            error: (_, _) => Text(
                              profile?.email ?? '—',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.slate400),
                            ),
                          ),
                          investorAsync.when(
                            data: (inv) => inv == null
                                ? const SizedBox.shrink()
                                : Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      'KYC: ${inv.kycStatus.replaceAll('_', ' ')}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppColors.slate400,
                                          ),
                                    ),
                                  ),
                            loading: () => const SizedBox.shrink(),
                            error: (_, _) => const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _StatusChip(
                                label: verification.emailVerified
                                    ? 'Email verified'
                                    : 'Email pending',
                                ok: verification.emailVerified,
                                onTap: () =>
                                    context.go(RoutePaths.verificationCenter),
                              ),
                              _StatusChip(
                                label: verification.phoneVerified
                                    ? 'Phone on file'
                                    : 'Add phone',
                                ok: verification.phoneVerified,
                                onTap: () =>
                                    context.go(RoutePaths.profileCenter),
                              ),
                              _StatusChip(
                                label: mfaOn ? 'MFA on' : 'MFA off',
                                ok: mfaOn,
                                onTap: () =>
                                    context.go(RoutePaths.securityCenter),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: AppColors.neutral700.withValues(alpha: 0.4),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _firstNameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'First name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _lastNameCtrl,
                      decoration: const InputDecoration(labelText: 'Last name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed:
                            _savingProfile ? null : _saveProfileEssentials,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.charcoal,
                        ),
                        icon: _savingProfile
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(LucideIcons.save, size: 16),
                        label: const Text('Save profile'),
                      ),
                    ),
                  ],
                ),
              ),
              _SettingsLink(
                icon: LucideIcons.user,
                title: 'Full profile center',
                onTap: () => context.go(RoutePaths.profileCenter),
              ),
              _SettingsLink(
                icon: LucideIcons.mail,
                title: 'Email verification',
                onTap: () => context.go(RoutePaths.verificationCenter),
              ),
              _SettingsLink(
                icon: LucideIcons.smartphone,
                title: 'Phone number',
                subtitle: verification.phoneVerified
                    ? (verification.phone ?? 'On file from registration')
                    : 'Add a phone number on your profile',
                onTap: () => context.go(RoutePaths.profileCenter),
              ),
              _SettingsLink(
                icon: LucideIcons.badgeCheck,
                title: 'KYC documents',
                onTap: () => context.go(RoutePaths.kycVerification),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const InvestorSectionHeader(
          title: 'Security Health',
          subtitle: 'MFA, sessions, and trusted devices',
        ),
        const InvestorPortalCard(
          child: PortalSecurityHealthPanel(),
        ),
        const SizedBox(height: 24),
        const InvestorSectionHeader(
          title: 'Share your experience',
          subtitle: 'Stories appear on Home & Opportunities after review',
        ),
        const PortalShareTestimonialCard(
          defaultRoleHint: 'HD Homes investor',
        ),
        const SizedBox(height: 24),
        const InvestorSectionHeader(title: 'KYC verification'),
        const _KycStatusSection(),
        const SizedBox(height: 24),
        const InvestorSectionHeader(title: 'Security actions'),
        InvestorPortalCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _SettingsLink(
                icon: LucideIcons.lock,
                title: 'Password & MFA',
                subtitle: mfaOn
                    ? 'Authenticator enabled'
                    : 'Enable two-factor authentication',
                onTap: () => context.go(RoutePaths.securityCenter),
              ),
              _SettingsLink(
                icon: LucideIcons.monitorSmartphone,
                title: 'Trusted devices',
                subtitle: '14 / 30 / 90 day MFA skip windows',
                onTap: () => showTrustedDevicesSheet(context, ref),
              ),
              _SettingsLink(
                icon: LucideIcons.smartphone,
                title: 'Active sessions',
                onTap: () => context.go(RoutePaths.activeSessions),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        InvestorSectionHeader(
          title: 'Notification preferences',
          action: TextButton(
            onPressed: _saving ? null : _savePreferences,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ),
        InvestorPortalCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Email notifications'),
                value: _emailNotifications,
                activeThumbColor: AppColors.gold,
                onChanged: (v) => setState(() => _emailNotifications = v),
              ),
              SwitchListTile(
                title: const Text('SMS notifications'),
                value: _smsNotifications,
                activeThumbColor: AppColors.gold,
                onChanged: (v) => setState(() => _smsNotifications = v),
              ),
              SwitchListTile(
                title: const Text('Push notifications'),
                value: _pushNotifications,
                activeThumbColor: AppColors.gold,
                onChanged: (v) => setState(() => _pushNotifications = v),
              ),
              SwitchListTile(
                title: const Text('Distribution alerts'),
                value: _distributionAlerts,
                activeThumbColor: AppColors.gold,
                onChanged: (v) => setState(() => _distributionAlerts = v),
              ),
              SwitchListTile(
                title: const Text('Performance alerts'),
                value: _performanceAlerts,
                activeThumbColor: AppColors.gold,
                onChanged: (v) => setState(() => _performanceAlerts = v),
              ),
              SwitchListTile(
                title: const Text('Construction updates'),
                value: _constructionAlerts,
                activeThumbColor: AppColors.gold,
                onChanged: (v) => setState(() => _constructionAlerts = v),
              ),
              ListTile(
                title: const Text('Theme'),
                trailing: DropdownButton<ThemeMode>(
                  value: _themeMode,
                  dropdownColor: AppColors.charcoal,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('System'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Light'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Dark'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _themeMode = v);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _savePreferences,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.charcoal,
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.save, size: 16),
                    label: const Text('Save preferences'),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const InvestorSectionHeader(title: 'Account'),
        InvestorPortalCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _SettingsLink(
                icon: LucideIcons.download,
                title: 'Download my data',
                subtitle: 'Export profile and preferences from this device',
                onTap: _exportMyData,
              ),
              _SettingsLink(
                icon: LucideIcons.sliders,
                title: 'Preference center',
                onTap: () => context.go(RoutePaths.preferenceCenter),
              ),
              _SettingsLink(
                icon: LucideIcons.logOut,
                title: 'Sign out',
                destructive: true,
                onTap: () async {
                  await ref.read(authControllerProvider.notifier).signOut();
                  if (context.mounted) context.go(RoutePaths.login);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.ok,
    required this.onTap,
  });

  final String label;
  final bool ok;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.success : AppColors.warning;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ok ? LucideIcons.checkCircle2 : LucideIcons.alertCircle,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsLink extends StatelessWidget {
  const _SettingsLink({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : AppColors.white;
    return ListTile(
      leading: Icon(icon, color: destructive ? AppColors.error : AppColors.gold),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: const TextStyle(color: AppColors.slate400),
            ),
      trailing: destructive
          ? null
          : const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.slate500),
      onTap: onTap,
    );
  }
}

class _KycStatusSection extends ConsumerWidget {
  const _KycStatusSection();

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'partially_approved':
        return AppColors.success;
      case 'under_review':
      case 'in_progress':
        return AppColors.info;
      case 'rejected':
      case 'suspended':
      case 'expired':
        return AppColors.error;
      case 'awaiting_documents':
      case 'needs_resubmission':
        return AppColors.warning;
      default:
        return AppColors.gold;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kycAsync = ref.watch(investorKycBundleProvider);
    final connection = ref.watch(investorRealtimeConnectionProvider);
    final live = connection == InvestorRealtimeConnection.live;

    return kycAsync.when(
      loading: () => const InvestorPortalCard(
        child: SizedBox(
          height: 48,
          child: Center(
            child: CircularProgressIndicator(
              color: AppColors.gold,
              strokeWidth: 2,
            ),
          ),
        ),
      ),
      error: (e, _) => InvestorPortalCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unable to load KYC status.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.slate400),
            ),
            TextButton(
              onPressed: () => ref.invalidate(investorKycBundleProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (bundle) {
        final color = _statusColor(bundle.kycStatus);
        return InvestorPortalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      LucideIcons.badgeCheck,
                      color: color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bundle.statusLabel.toUpperCase(),
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          bundle.needsAction
                              ? 'Action may be required — open KYC documents to continue.'
                              : 'Verification is managed by HD Homes compliance.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.slate400,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  _KycLiveChip(live: live, connection: connection),
                ],
              ),
              if (bundle.sourceOfFunds != null ||
                  bundle.riskProfile != null ||
                  bundle.investmentSource != null) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (bundle.riskProfile != null)
                      _MetaChip(
                        label: 'Risk: ${bundle.riskProfile}',
                      ),
                    if (bundle.sourceOfFunds != null)
                      _MetaChip(
                        label: 'Funds: ${bundle.sourceOfFunds}',
                      ),
                    if (bundle.investmentSource != null)
                      _MetaChip(
                        label: 'Source: ${bundle.investmentSource}',
                      ),
                  ],
                ),
              ],
              if (bundle.reviews.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Review history',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                for (final review in bundle.reviews.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _KycReviewTile(review: review),
                  ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => context.go(RoutePaths.kycVerification),
                  icon: const Icon(LucideIcons.externalLink, size: 16),
                  label: Text(
                    bundle.needsAction
                        ? 'Continue KYC'
                        : 'Open KYC documents',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    side: const BorderSide(color: AppColors.gold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _KycReviewTile extends StatelessWidget {
  const _KycReviewTile({required this.review});

  final InvestorKycReview review;

  @override
  Widget build(BuildContext context) {
    final when = review.reviewedAt ?? review.createdAt;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.neutral800.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            review.statusLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (review.notes != null && review.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              review.notes!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.slate400,
                  ),
            ),
          ],
          if (when != null) ...[
            const SizedBox(height: 4),
            Text(
              DateFormat.yMMMd().add_jm().format(when.toLocal()),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.slate400,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.neutral700.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.slate400,
            ),
      ),
    );
  }
}

class _KycLiveChip extends StatelessWidget {
  const _KycLiveChip({required this.live, required this.connection});

  final bool live;
  final InvestorRealtimeConnection connection;

  @override
  Widget build(BuildContext context) {
    if (live || connection == InvestorRealtimeConnection.connecting) {
      return const SizedBox.shrink();
    }
    return const OfflineUpdatesNote();
  }
}
