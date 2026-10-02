import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/theme_provider.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/portal_share_testimonial_card.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/profile_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/kyc_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/mfa_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/profile_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/verification_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/portal_security_health_panel.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_providers.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_portal_widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

/// Client portal settings — profile, identity, security, preferences, privacy.
class ClientSettingsPage extends ConsumerStatefulWidget {
  const ClientSettingsPage({super.key});

  @override
  ConsumerState<ClientSettingsPage> createState() => _ClientSettingsPageState();
}

class _ClientSettingsPageState extends ConsumerState<ClientSettingsPage> {
  bool _emailNotifications = true;
  bool _smsNotifications = true;
  bool _pushNotifications = true;
  bool _constructionAlerts = true;
  bool _paymentReminders = true;
  String _language = 'en';
  ThemeMode _themeMode = ThemeMode.system;
  var _prefsApplied = false;
  bool _saving = false;
  bool _savingProfile = false;
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _phoneCtrl;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController();
    _lastNameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
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
    final session = ref.read(identitySessionProvider);
    final profile = session.profile;
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
            content: Text(
              ok ? 'Profile updated' : 'Could not update profile',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  EdgeInsets _padding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return EdgeInsets.all(w >= AppBreakpoints.tablet ? 24 : 16);
  }

  void _applyPreferences(Map<String, dynamic> prefs) {
    _emailNotifications = prefs['email_notifications'] as bool? ?? true;
    _smsNotifications = prefs['sms_notifications'] as bool? ?? true;
    _pushNotifications = prefs['push_notifications'] as bool? ?? true;
    _constructionAlerts = prefs['construction_alerts'] as bool? ?? true;
    _paymentReminders = prefs['payment_reminders'] as bool? ?? true;
    _language = prefs['language'] as String? ?? 'en';
    final theme = prefs['theme'] as String? ?? 'system';
    _themeMode = switch (theme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> _savePreferences() async {
    final record = await ref.read(clientRecordProvider.future);
    if (record == null) return;
    setState(() => _saving = true);
    try {
      final theme = switch (_themeMode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await ref.read(clientServiceProvider).savePreferences(record.id, {
        'email_notifications': _emailNotifications,
        'sms_notifications': _smsNotifications,
        'push_notifications': _pushNotifications,
        'construction_alerts': _constructionAlerts,
        'payment_reminders': _paymentReminders,
        'language': _language,
        'theme': theme,
      });
      await ref.read(themeModeProvider.notifier).setThemeMode(_themeMode);
      ref.invalidate(clientPreferencesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferences saved')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportMyData() async {
    final session = ref.read(identitySessionProvider);
    final profile = session.profile;
    final prefs = ref.read(clientPreferencesProvider).valueOrNull ?? {};
    final verification = ref.read(verificationSnapshotProvider);
    final mfa = ref.read(mfaStatusProvider).valueOrNull;
    final kyc = ref.read(kycHubProvider).valueOrNull;

    final payload = {
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'portal': 'client',
      'profile': {
        'id': profile?.id,
        'email': profile?.email ?? session.email,
        'first_name': profile?.firstName,
        'last_name': profile?.lastName,
        'phone': profile?.phone,
      },
      'verification': {
        'email_verified': verification.emailVerified,
        'phone_verified': verification.phoneVerified,
      },
      'mfa_enabled': mfa?.enabled ?? false,
      'kyc_status': kyc?.status.slug,
      'preferences': prefs,
    };

    final json = const JsonEncoder.withIndent('  ').convert(payload);
    await Clipboard.setData(ClipboardData(text: json));
    try {
      await Share.share(json, subject: 'HD Homes — my data export');
    } catch (_) {
      // Clipboard already set.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your data was copied and shared from this device.'),
      ),
    );
  }

  Future<void> _requestAccountDeletion() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: const Text('Request account deletion?'),
        content: const Text(
          'This opens Contact so you can request deletion. '
          'Your account stays active until HD Homes processes the request.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue to Contact'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      context.go('${RoutePaths.contact}?intent=account_deletion');
    }
  }

  Widget _statusChip({
    required String label,
    required bool ok,
    required VoidCallback onTap,
  }) {
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

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(identitySessionProvider);
    final profile = session.profile;
    final prefsAsync = ref.watch(clientPreferencesProvider);
    final verification = ref.watch(verificationSnapshotProvider);
    final mfaAsync = ref.watch(mfaStatusProvider);
    final kycAsync = ref.watch(kycHubProvider);
    final mfaOn = mfaAsync.valueOrNull?.enabled ?? false;
    final kycLabel = kycAsync.valueOrNull?.status.label ?? 'Not started';

    ref.listen(clientPreferencesProvider, (previous, next) {
      next.whenData((prefs) {
        if (!mounted) return;
        setState(() => _applyPreferences(prefs));
      });
    });

    final displayName = [
      profile?.firstName,
      profile?.lastName,
    ].whereType<String>().join(' ').trim();
    final initial = () {
      final fn = profile?.firstName;
      final em = profile?.email ?? session.email;
      if (fn != null && fn.isNotEmpty) return fn[0].toUpperCase();
      if (em != null && em.isNotEmpty) return em[0].toUpperCase();
      return 'C';
    }();

    // Keep essentials editors in sync when profile reloads.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncProfileFields();
    });

    return prefsAsync.when(
      skipLoadingOnReload: true,
      loading: () => const ClientPageSkeleton(showKpis: false, rows: 4),
      error: (e, _) => ClientErrorView(
        message: e,
        onRetry: () => ref.invalidate(clientPreferencesProvider),
      ),
      data: (prefs) {
        if (!_prefsApplied) {
          _prefsApplied = true;
          _applyPreferences(prefs);
        }
        return ListView(
          padding: _padding(context),
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
              'Profile, verification, security, and preferences for your client account.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
            ),
            const SizedBox(height: 20),
            ClientPortalCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.gold.withValues(alpha: 0.2),
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
                                  fontSize: 20,
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
                              displayName.isEmpty ? 'Client' : displayName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              profile?.email ?? session.email ?? '—',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.gold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _statusChip(
                        label: verification.emailVerified
                            ? 'Email verified'
                            : 'Email pending',
                        ok: verification.emailVerified,
                        onTap: () =>
                            context.go(RoutePaths.verificationCenter),
                      ),
                      _statusChip(
                        label: verification.phoneVerified
                            ? 'Phone on file'
                            : 'Add phone',
                        ok: verification.phoneVerified,
                        onTap: () => context.go(RoutePaths.profileCenter),
                      ),
                      _statusChip(
                        label: mfaOn ? 'MFA on' : 'MFA off',
                        ok: mfaOn,
                        onTap: () => context.go(RoutePaths.securityCenter),
                      ),
                      _statusChip(
                        label: 'KYC: $kycLabel',
                        ok: kycAsync.valueOrNull?.status.isTerminalSuccess ??
                            false,
                        onTap: () => context.go(RoutePaths.kycVerification),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const ClientSectionHeader(
              title: 'Security Health',
              subtitle: 'MFA, sessions, and trusted devices',
            ),
            const ClientPortalCard(
              child: PortalSecurityHealthPanel(),
            ),
            const SizedBox(height: 24),
            const ClientSectionHeader(title: 'Profile'),
            ClientPortalCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _firstNameCtrl,
                    decoration: const InputDecoration(labelText: 'First name'),
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
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _savingProfile ? null : _saveProfileEssentials,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.charcoal,
                      ),
                      icon: _savingProfile
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(LucideIcons.save, size: 16),
                      label: const Text('Save profile'),
                    ),
                  ),
                  const Divider(height: 28),
                  _LinkTile(
                    icon: LucideIcons.user,
                    title: 'Full profile center',
                    subtitle: 'Avatar, address, notifications, privacy',
                    onTap: () => context.go(RoutePaths.profileCenter),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const ClientSectionHeader(
              title: 'Identity & KYC',
              subtitle: 'Email, phone, and document verification',
            ),
            ClientPortalCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _LinkTile(
                    icon: LucideIcons.mail,
                    title: 'Email verification',
                    subtitle: verification.emailVerified
                        ? 'Email verified'
                        : 'Verify your email address',
                    onTap: () => context.go(RoutePaths.verificationCenter),
                  ),
                  _LinkTile(
                    icon: LucideIcons.smartphone,
                    title: 'Phone number',
                    subtitle: verification.phoneVerified
                        ? (verification.phone ?? 'On file from registration')
                        : 'Add a phone number on your profile',
                    onTap: () => context.go(RoutePaths.profileCenter),
                  ),
                  _LinkTile(
                    icon: LucideIcons.badgeCheck,
                    title: 'KYC documents',
                    subtitle: 'Status: $kycLabel',
                    onTap: () => context.go(RoutePaths.kycVerification),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const ClientSectionHeader(title: 'Security actions'),
            ClientPortalCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _LinkTile(
                    icon: LucideIcons.lock,
                    title: 'Password & MFA',
                    subtitle: mfaOn
                        ? 'Authenticator enabled'
                        : 'Enable two-factor authentication',
                    onTap: () => context.go(RoutePaths.securityCenter),
                  ),
                  _LinkTile(
                    icon: LucideIcons.monitorSmartphone,
                    title: 'Trusted devices',
                    subtitle: '14 / 30 / 90 day MFA skip windows',
                    onTap: () => showTrustedDevicesSheet(context, ref),
                  ),
                  _LinkTile(
                    icon: LucideIcons.smartphone,
                    title: 'Active sessions',
                    onTap: () => context.go(RoutePaths.activeSessions),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const ClientSectionHeader(
              title: 'Share your experience',
              subtitle: 'Stories appear on Home & Opportunities after review',
            ),
            const PortalShareTestimonialCard(
              defaultRoleHint: 'HD Homes client',
            ),
            const SizedBox(height: 24),
            ClientSectionHeader(
              title: 'Preferences',
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
            ClientPortalCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Email notifications'),
                    value: _emailNotifications,
                    activeThumbColor: AppColors.gold,
                    onChanged: (v) =>
                        setState(() => _emailNotifications = v),
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
                    title: const Text('Construction updates'),
                    value: _constructionAlerts,
                    activeThumbColor: AppColors.gold,
                    onChanged: (v) =>
                        setState(() => _constructionAlerts = v),
                  ),
                  SwitchListTile(
                    title: const Text('Payment reminders'),
                    value: _paymentReminders,
                    activeThumbColor: AppColors.gold,
                    onChanged: (v) => setState(() => _paymentReminders = v),
                  ),
                  ListTile(
                    title: const Text('Language'),
                    trailing: DropdownButton<String>(
                      value: _language,
                      dropdownColor: AppColors.charcoal,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'fr', child: Text('Français')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _language = v);
                      },
                    ),
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
                        icon: const Icon(LucideIcons.save, size: 16),
                        label: const Text('Save preferences'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const ClientSectionHeader(title: 'Privacy'),
            ClientPortalCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _LinkTile(
                    icon: LucideIcons.download,
                    title: 'Download my data',
                    subtitle: 'Export profile and preferences from this device',
                    onTap: _exportMyData,
                  ),
                  _LinkTile(
                    icon: LucideIcons.sliders,
                    title: 'Privacy & consent',
                    onTap: () => context.go(RoutePaths.preferenceCenter),
                  ),
                  _LinkTile(
                    icon: LucideIcons.userX,
                    title: 'Delete account',
                    subtitle: 'Request deletion via Contact',
                    destructive: true,
                    onTap: _requestAccountDeletion,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ClientPortalCard(
              padding: EdgeInsets.zero,
              child: _LinkTile(
                icon: LucideIcons.logOut,
                title: 'Sign out',
                destructive: true,
                onTap: () async {
                  await ref.read(authControllerProvider.notifier).signOut();
                  if (context.mounted) context.go(RoutePaths.login);
                },
              ),
            ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
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
      leading: Icon(
        icon,
        color: destructive ? AppColors.error : AppColors.gold,
      ),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: const TextStyle(color: AppColors.textSecondaryDark),
            ),
      trailing: destructive
          ? null
          : const Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: AppColors.slate500,
            ),
      onTap: onTap,
    );
  }
}
