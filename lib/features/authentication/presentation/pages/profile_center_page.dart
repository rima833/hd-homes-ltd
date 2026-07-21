import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/core/widgets/feedback/confirmation_dialog.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/profile_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/profile_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Enterprise Profile Center — Dynamic User Identity™ hub for all roles.
class ProfileCenterPage extends HookConsumerWidget {
  const ProfileCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hubAsync = ref.watch(profileHubProvider);
    final ui = ref.watch(profileControllerProvider);
    final controller = ref.read(profileControllerProvider.notifier);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            tooltip: 'Security Center',
            icon: const Icon(LucideIcons.shield),
            onPressed: () => context.go(RoutePaths.securityCenter),
          ),
        ],
      ),
      body: hubAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text('Unable to load profile: $e', textAlign: TextAlign.center),
          ),
        ),
        data: (hub) {
          if (hub == null) {
            return const Center(child: Text('Sign in to manage your profile.'));
          }
          final sections = DynamicUserIdentity.sectionsFor(hub.profile.primaryRole);
          final section = sections.contains(ui.section)
              ? ui.section
              : sections.first;

          return Column(
            children: [
              if (ui.message != null)
                MaterialBanner(
                  content: Text(ui.message!),
                  backgroundColor: AppColors.success.withValues(alpha: 0.15),
                  actions: [
                    TextButton(
                      onPressed: () => controller.selectSection(section),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              if (ui.error != null)
                MaterialBanner(
                  content: Text(ui.error!, style: const TextStyle(color: AppColors.error)),
                  actions: [
                    TextButton(
                      onPressed: () => controller.selectSection(section),
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              Expanded(
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 220,
                            child: _SectionNav(
                              sections: sections,
                              selected: section,
                              onSelect: controller.selectSection,
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(
                            child: _SectionBody(
                              hub: hub,
                              section: section,
                              isBusy: ui.isBusy,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          SizedBox(
                            height: 48,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              children: sections
                                  .map(
                                    (s) => Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        label: Text(s.label),
                                        selected: s == section,
                                        onSelected: (_) =>
                                            controller.selectSection(s),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          Expanded(
                            child: _SectionBody(
                              hub: hub,
                              section: section,
                              isBusy: ui.isBusy,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionNav extends StatelessWidget {
  const _SectionNav({
    required this.sections,
    required this.selected,
    required this.onSelect,
  });

  final List<ProfileSection> sections;
  final ProfileSection selected;
  final ValueChanged<ProfileSection> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      children: sections
          .map(
            (s) => ListTile(
              selected: s == selected,
              selectedTileColor: AppColors.gold.withValues(alpha: 0.12),
              title: Text(s.label),
              onTap: () => onSelect(s),
            ),
          )
          .toList(),
    );
  }
}

class _SectionBody extends ConsumerWidget {
  const _SectionBody({
    required this.hub,
    required this.section,
    required this.isBusy,
  });

  final ProfileHubSnapshot hub;
  final ProfileSection section;
  final bool isBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: KeyedSubtree(
        key: ValueKey(section),
        child: switch (section) {
          ProfileSection.overview => _OverviewSection(hub: hub),
          ProfileSection.personal => _PersonalSection(hub: hub, isBusy: isBusy),
          ProfileSection.contact => _ContactSection(hub: hub, isBusy: isBusy),
          ProfileSection.company => _CompanySection(hub: hub, isBusy: isBusy),
          ProfileSection.communication =>
            _CommunicationSection(hub: hub, isBusy: isBusy),
          ProfileSection.regional ||
          ProfileSection.appearance ||
          ProfileSection.privacy =>
            _PreferencesSection(hub: hub, section: section, isBusy: isBusy),
          ProfileSection.connected => const _ConnectedSection(),
          ProfileSection.summary => _SummarySection(hub: hub),
        },
      ),
    );
  }
}

class _OverviewSection extends ConsumerWidget {
  const _OverviewSection({required this.hub});

  final ProfileHubSnapshot hub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = hub.profile;
    final controller = ref.read(profileControllerProvider.notifier);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Row(
          children: [
            ProfileAvatar(
              imageUrl: p.avatarUrl,
              name: p.displayName,
              size: 88,
              onTap: () => controller.pickAndUploadAvatar(p.id),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.displayName, style: Theme.of(context).textTheme.headlineSmall),
                  Text(p.email),
                  if (p.primaryRole != null)
                    Text(
                      p.primaryRole!.displayName,
                      style: const TextStyle(color: AppColors.gold),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (p.emailVerified)
                        const Chip(
                          avatar: Icon(LucideIcons.badgeCheck, size: 16),
                          label: Text('Email'),
                        ),
                      if (p.phoneVerified)
                        const Chip(
                          avatar: Icon(LucideIcons.smartphone, size: 16),
                          label: Text('Phone'),
                        ),
                      if (hub.mfaEnabled)
                        const Chip(
                          avatar: Icon(LucideIcons.shieldCheck, size: 16),
                          label: Text('MFA'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => controller.pickAndUploadAvatar(p.id),
              icon: const Icon(LucideIcons.upload, size: 16),
              label: const Text('Upload photo'),
            ),
            if (p.avatarUrl != null)
              TextButton(
                onPressed: () => controller.removeAvatar(p.id),
                child: const Text('Remove'),
              ),
          ],
        ),
        const Divider(height: AppSpacing.xxl),
        Text('Profile completion', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        LinearProgressIndicator(
          value: hub.completion.percent / 100,
          minHeight: 10,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          color: AppColors.gold,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('${hub.completion.percent}% complete · Account health ${hub.accountHealth}/100'),
        const SizedBox(height: AppSpacing.base),
        ...hub.completion.missing.take(5).map(
              (item) => ListTile(
                dense: true,
                leading: const Icon(LucideIcons.circle, size: 16, color: AppColors.gold),
                title: Text(item.label),
                trailing: item.actionPath != null
                    ? TextButton(
                        onPressed: () => context.go(item.actionPath!),
                        child: Text(item.actionLabel ?? 'Fix'),
                      )
                    : Text(item.actionLabel ?? '', style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
        const Divider(height: AppSpacing.xxl),
        ListTile(
          leading: const Icon(LucideIcons.slidersHorizontal),
          title: const Text('Preference Center'),
          subtitle: const Text('Theme, dashboard, favorites, accessibility'),
          onTap: () => context.go(RoutePaths.preferenceCenter),
        ),
        ListTile(
          leading: const Icon(LucideIcons.sparkles),
          title: const Text('AI Workspace'),
          subtitle: const Text('Digital assistant & copilots'),
          onTap: () => context.go(RoutePaths.aiWorkspace),
        ),
        ListTile(
          leading: const Icon(LucideIcons.shield),
          title: const Text('Security Center'),
          subtitle: const Text('Password, MFA, sessions'),
          onTap: () => context.go(RoutePaths.securityCenter),
        ),
        ListTile(
          leading: const Icon(LucideIcons.badgeCheck),
          title: const Text('Verification'),
          subtitle: const Text('Email & phone'),
          onTap: () => context.go(RoutePaths.verificationCenter),
        ),
        ListTile(
          leading: const Icon(LucideIcons.fingerprint),
          title: const Text('Identity Verification (KYC)'),
          subtitle: const Text('Documents, trust level, compliance'),
          onTap: () => context.go(RoutePaths.kycVerification),
        ),
      ],
    );
  }
}

class _PersonalSection extends HookConsumerWidget {
  const _PersonalSection({required this.hub, required this.isBusy});

  final ProfileHubSnapshot hub;
  final bool isBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = hub.profile;
    final first = useTextEditingController(text: p.firstName ?? '');
    final middle = useTextEditingController(text: p.middleName ?? '');
    final last = useTextEditingController(text: p.lastName ?? '');
    final preferred = useTextEditingController(text: p.preferredName ?? '');
    final occupation = useTextEditingController(text: p.occupation ?? '');
    final nationality = useTextEditingController(text: p.nationality ?? '');
    final bio = useTextEditingController(text: p.biography ?? '');
    final gender = useState(p.gender);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text('Personal information', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.lg),
        TextField(controller: first, decoration: const InputDecoration(labelText: 'First name')),
        const SizedBox(height: AppSpacing.md),
        TextField(controller: middle, decoration: const InputDecoration(labelText: 'Middle name')),
        const SizedBox(height: AppSpacing.md),
        TextField(controller: last, decoration: const InputDecoration(labelText: 'Last name')),
        const SizedBox(height: AppSpacing.md),
        TextField(controller: preferred, decoration: const InputDecoration(labelText: 'Preferred name')),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String?>(
          // ignore: deprecated_member_use
          value: gender.value,
          decoration: const InputDecoration(labelText: 'Gender (optional)'),
          items: const [
            DropdownMenuItem(value: null, child: Text('Prefer not to say')),
            DropdownMenuItem(value: 'female', child: Text('Female')),
            DropdownMenuItem(value: 'male', child: Text('Male')),
            DropdownMenuItem(value: 'other', child: Text('Other')),
          ],
          onChanged: (v) => gender.value = v,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(controller: occupation, decoration: const InputDecoration(labelText: 'Occupation')),
        const SizedBox(height: AppSpacing.md),
        TextField(controller: nationality, decoration: const InputDecoration(labelText: 'Nationality')),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: bio,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'About me'),
        ),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: 'Save personal info',
          expand: true,
          isLoading: isBusy,
          onPressed: isBusy
              ? null
              : () => ref.read(profileControllerProvider.notifier).savePersonal(
                    p.copyWith(
                      firstName: first.text,
                      middleName: middle.text,
                      lastName: last.text,
                      preferredName: preferred.text,
                      gender: gender.value,
                      occupation: occupation.text,
                      nationality: nationality.text,
                      biography: bio.text,
                    ),
                  ),
        ),
      ],
    );
  }
}

class _ContactSection extends HookConsumerWidget {
  const _ContactSection({required this.hub, required this.isBusy});

  final ProfileHubSnapshot hub;
  final bool isBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = hub.profile;
    final phone = useTextEditingController(text: p.phone ?? '');
    final secondary = useTextEditingController(text: p.secondaryPhone ?? '');
    final whatsapp = useTextEditingController(text: p.whatsapp ?? '');
    final country = useTextEditingController(text: p.country ?? 'Nigeria');
    final state = useTextEditingController(text: p.state ?? '');
    final city = useTextEditingController(text: p.city ?? '');
    final address = useTextEditingController(text: p.address ?? '');
    final postal = useTextEditingController(text: p.postalCode ?? '');

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text('Contact information', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Email'),
          subtitle: Text(p.email),
          trailing: TextButton(
            onPressed: () => context.go(RoutePaths.verificationCenter),
            child: Text(p.emailVerified ? 'Verified' : 'Verify'),
          ),
        ),
        const Text(
          'Changing email requires re-verification via the Verification Center.',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
        const SizedBox(height: AppSpacing.md),
        TextField(controller: secondary, decoration: const InputDecoration(labelText: 'Secondary phone')),
        const SizedBox(height: AppSpacing.md),
        TextField(controller: whatsapp, decoration: const InputDecoration(labelText: 'WhatsApp')),
        const SizedBox(height: AppSpacing.md),
        TextField(controller: country, decoration: const InputDecoration(labelText: 'Country')),
        const SizedBox(height: AppSpacing.md),
        TextField(controller: state, decoration: const InputDecoration(labelText: 'State')),
        const SizedBox(height: AppSpacing.md),
        TextField(controller: city, decoration: const InputDecoration(labelText: 'City')),
        const SizedBox(height: AppSpacing.md),
        TextField(controller: address, decoration: const InputDecoration(labelText: 'Address'), maxLines: 2),
        const SizedBox(height: AppSpacing.md),
        TextField(controller: postal, decoration: const InputDecoration(labelText: 'Postal code')),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: 'Save contact info',
          expand: true,
          isLoading: isBusy,
          onPressed: isBusy
              ? null
              : () => ref.read(profileControllerProvider.notifier).savePersonal(
                    p.copyWith(
                      phone: phone.text,
                      secondaryPhone: secondary.text,
                      whatsapp: whatsapp.text,
                      country: country.text,
                      state: state.text,
                      city: city.text,
                      address: address.text,
                      postalCode: postal.text,
                    ),
                  ),
        ),
        TextButton(
          onPressed: () => context.go(RoutePaths.verifyPhone),
          child: const Text('Verify phone number'),
        ),
      ],
    );
  }
}

class _CompanySection extends HookConsumerWidget {
  const _CompanySection({required this.hub, required this.isBusy});

  final ProfileHubSnapshot hub;
  final bool isBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = hub.company;
    final name = useTextEditingController(text: c.companyName ?? '');
    final type = useTextEditingController(text: c.businessType ?? '');
    final reg = useTextEditingController(text: c.registrationNumber ?? '');
    final tax = useTextEditingController(text: c.taxId ?? '');
    final position = useTextEditingController(text: c.position ?? '');
    final address = useTextEditingController(text: c.companyAddress ?? '');
    final website = useTextEditingController(text: c.companyWebsite ?? '');

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text('Company information', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.lg),
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Company name')),
        const SizedBox(height: AppSpacing.md),
        TextField(controller: type, decoration: const InputDecoration(labelText: 'Business type')),
        const SizedBox(height: AppSpacing.md),
        TextField(controller: reg, decoration: const InputDecoration(labelText: 'Registration number')),
        const SizedBox(height: AppSpacing.md),
        TextField(controller: tax, decoration: const InputDecoration(labelText: 'Tax ID')),
        const SizedBox(height: AppSpacing.md),
        TextField(controller: position, decoration: const InputDecoration(labelText: 'Your position')),
        const SizedBox(height: AppSpacing.md),
        TextField(controller: address, decoration: const InputDecoration(labelText: 'Company address'), maxLines: 2),
        const SizedBox(height: AppSpacing.md),
        TextField(controller: website, decoration: const InputDecoration(labelText: 'Website')),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: 'Save company profile',
          expand: true,
          isLoading: isBusy,
          onPressed: isBusy
              ? null
              : () => ref.read(profileControllerProvider.notifier).saveCompany(
                    hub.profile.id,
                    CompanyProfile(
                      companyName: name.text,
                      businessType: type.text,
                      registrationNumber: reg.text,
                      taxId: tax.text,
                      position: position.text,
                      companyAddress: address.text,
                      companyWebsite: website.text,
                    ),
                  ),
        ),
      ],
    );
  }
}

class _CommunicationSection extends HookConsumerWidget {
  const _CommunicationSection({required this.hub, required this.isBusy});

  final ProfileHubSnapshot hub;
  final bool isBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = useState(hub.communication);

    void set(CommunicationPreferences next) => prefs.value = next;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text('Communication preferences', style: Theme.of(context).textTheme.titleLarge),
        SwitchListTile(
          title: const Text('Email notifications'),
          value: prefs.value.emailEnabled,
          onChanged: (v) => set(prefs.value.copyWith(emailEnabled: v)),
        ),
        SwitchListTile(
          title: const Text('SMS notifications'),
          value: prefs.value.smsEnabled,
          onChanged: (v) => set(prefs.value.copyWith(smsEnabled: v)),
        ),
        SwitchListTile(
          title: const Text('Push notifications'),
          value: prefs.value.pushEnabled,
          onChanged: (v) => set(prefs.value.copyWith(pushEnabled: v)),
        ),
        SwitchListTile(
          title: const Text('WhatsApp notifications'),
          value: prefs.value.whatsappEnabled,
          onChanged: (v) => set(prefs.value.copyWith(whatsappEnabled: v)),
        ),
        SwitchListTile(
          title: const Text('Security alerts'),
          value: prefs.value.securityAlerts,
          onChanged: (v) => set(prefs.value.copyWith(securityAlerts: v)),
        ),
        SwitchListTile(
          title: const Text('Investment updates'),
          value: prefs.value.investmentUpdates,
          onChanged: (v) => set(prefs.value.copyWith(investmentUpdates: v)),
        ),
        SwitchListTile(
          title: const Text('Property alerts'),
          value: prefs.value.propertyAlerts,
          onChanged: (v) => set(prefs.value.copyWith(propertyAlerts: v)),
        ),
        SwitchListTile(
          title: const Text('Marketing emails'),
          value: prefs.value.marketingEmail,
          onChanged: (v) => set(prefs.value.copyWith(marketingEmail: v)),
        ),
        SwitchListTile(
          title: const Text('Newsletters'),
          value: prefs.value.newsletters,
          onChanged: (v) => set(prefs.value.copyWith(newsletters: v)),
        ),
        SwitchListTile(
          title: const Text('Product announcements'),
          value: prefs.value.productAnnouncements,
          onChanged: (v) => set(prefs.value.copyWith(productAnnouncements: v)),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Save preferences',
          expand: true,
          isLoading: isBusy,
          onPressed: isBusy
              ? null
              : () => ref.read(profileControllerProvider.notifier).saveCommunication(
                    hub.profile.id,
                    prefs.value,
                  ),
        ),
      ],
    );
  }
}

class _PreferencesSection extends HookConsumerWidget {
  const _PreferencesSection({
    required this.hub,
    required this.section,
    required this.isBusy,
  });

  final ProfileHubSnapshot hub;
  final ProfileSection section;
  final bool isBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = useState(hub.appPreferences);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text(
          section == ProfileSection.regional
              ? 'Language & regional'
              : section == ProfileSection.appearance
                  ? 'Appearance'
                  : 'Privacy',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (section == ProfileSection.regional) ...[
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: prefs.value.locale,
            decoration: const InputDecoration(labelText: 'Language'),
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'fr', child: Text('French (soon)')),
            ],
            onChanged: (v) {
              if (v != null) prefs.value = prefs.value.copyWith(locale: v);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: prefs.value.currency,
            decoration: const InputDecoration(labelText: 'Currency'),
            items: const [
              DropdownMenuItem(value: 'NGN', child: Text('NGN')),
              DropdownMenuItem(value: 'USD', child: Text('USD')),
              DropdownMenuItem(value: 'GBP', child: Text('GBP')),
            ],
            onChanged: (v) {
              if (v != null) prefs.value = prefs.value.copyWith(currency: v);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: prefs.value.timezone,
            decoration: const InputDecoration(labelText: 'Timezone'),
            items: const [
              DropdownMenuItem(value: 'Africa/Lagos', child: Text('Africa/Lagos')),
              DropdownMenuItem(value: 'UTC', child: Text('UTC')),
            ],
            onChanged: (v) {
              if (v != null) prefs.value = prefs.value.copyWith(timezone: v);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: prefs.value.dateFormat,
            decoration: const InputDecoration(labelText: 'Date format'),
            items: const [
              DropdownMenuItem(value: 'dd/MM/yyyy', child: Text('DD/MM/YYYY')),
              DropdownMenuItem(value: 'MM/dd/yyyy', child: Text('MM/DD/YYYY')),
              DropdownMenuItem(value: 'yyyy-MM-dd', child: Text('YYYY-MM-DD')),
            ],
            onChanged: (v) {
              if (v != null) prefs.value = prefs.value.copyWith(dateFormat: v);
            },
          ),
        ],
        if (section == ProfileSection.appearance) ...[
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: prefs.value.theme,
            decoration: const InputDecoration(labelText: 'Theme'),
            items: const [
              DropdownMenuItem(value: 'system', child: Text('System')),
              DropdownMenuItem(value: 'light', child: Text('Light')),
              DropdownMenuItem(value: 'dark', child: Text('Dark')),
            ],
            onChanged: (v) {
              if (v != null) prefs.value = prefs.value.copyWith(theme: v);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text('Theme preference is saved to your account. Full app theming applies in a later release.'),
        ],
        if (section == ProfileSection.privacy) ...[
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: prefs.value.profileVisibility,
            decoration: const InputDecoration(labelText: 'Profile visibility'),
            items: const [
              DropdownMenuItem(value: 'private', child: Text('Private')),
              DropdownMenuItem(value: 'staff', child: Text('Staff only')),
              DropdownMenuItem(value: 'public', child: Text('Public (limited)')),
            ],
            onChanged: (v) {
              if (v != null) {
                prefs.value = prefs.value.copyWith(profileVisibility: v);
              }
            },
          ),
          SwitchListTile(
            title: const Text('Marketing opt-in'),
            value: prefs.value.marketingOptIn,
            onChanged: (v) => prefs.value = prefs.value.copyWith(marketingOptIn: v),
          ),
          SwitchListTile(
            title: const Text('Product updates'),
            value: prefs.value.productUpdatesOptIn,
            onChanged: (v) =>
                prefs.value = prefs.value.copyWith(productUpdatesOptIn: v),
          ),
          SwitchListTile(
            title: const Text('Cookie preferences accepted'),
            value: prefs.value.cookiePreferencesAccepted,
            onChanged: (v) =>
                prefs.value = prefs.value.copyWith(cookiePreferencesAccepted: v),
          ),
          SwitchListTile(
            title: const Text('Allow anonymized data sharing'),
            value: prefs.value.dataSharingOptIn,
            onChanged: (v) =>
                prefs.value = prefs.value.copyWith(dataSharingOptIn: v),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: 'Save',
          expand: true,
          isLoading: isBusy,
          onPressed: isBusy
              ? null
              : () => ref.read(profileControllerProvider.notifier).saveAppPreferences(
                    hub.profile.id,
                    prefs.value,
                  ),
        ),
      ],
    );
  }
}

class _ConnectedSection extends StatelessWidget {
  const _ConnectedSection();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text('Connected accounts', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        const Text('Link Google, Microsoft, or Apple when social login is enabled.'),
        const SizedBox(height: AppSpacing.lg),
        ListTile(
          leading: const Icon(LucideIcons.chrome),
          title: const Text('Google'),
          subtitle: const Text('Coming soon'),
          trailing: const Chip(label: Text('Soon')),
        ),
        ListTile(
          leading: const Icon(LucideIcons.laptop),
          title: const Text('Microsoft'),
          subtitle: const Text('Coming soon'),
          trailing: const Chip(label: Text('Soon')),
        ),
        ListTile(
          leading: const Icon(LucideIcons.apple),
          title: const Text('Apple'),
          subtitle: const Text('Coming soon'),
          trailing: const Chip(label: Text('Soon')),
        ),
      ],
    );
  }
}

class _SummarySection extends ConsumerWidget {
  const _SummarySection({required this.hub});

  final ProfileHubSnapshot hub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = hub.profile;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text('Account summary', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.lg),
        ListTile(
          title: const Text('Member since'),
          subtitle: Text(p.createdAt?.toLocal().toString().split(' ').first ?? '—'),
        ),
        ListTile(
          title: const Text('Account status'),
          subtitle: Text(p.accountStatus ?? '—'),
        ),
        ListTile(
          title: const Text('Profile completion'),
          subtitle: Text('${hub.completion.percent}%'),
        ),
        ListTile(
          title: const Text('Account health'),
          subtitle: Text('${hub.accountHealth} / 100'),
        ),
        ListTile(
          title: const Text('Last login'),
          subtitle: Text(p.lastLoginAt?.toLocal().toString() ?? '—'),
        ),
        const Divider(height: AppSpacing.xxl),
        Text('Digital Identity Timeline', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (hub.activity.isEmpty)
          const Text('Profile activity will appear here as you update your account.')
        else
          ...hub.activity.map(
            (a) => ListTile(
              dense: true,
              leading: const Icon(LucideIcons.activity, size: 18),
              title: Text(a.eventType.replaceAll('_', ' ')),
              subtitle: Text(a.createdAt.toLocal().toString()),
            ),
          ),
        const Divider(height: AppSpacing.xxl),
        ListTile(
          leading: const Icon(LucideIcons.monitor),
          title: const Text('Active sessions'),
          onTap: () => context.go(RoutePaths.activeSessions),
        ),
        ListTile(
          leading: const Icon(LucideIcons.history),
          title: const Text('Activity Timeline'),
          onTap: () => context.go(RoutePaths.activityTimeline),
        ),
        ListTile(
          leading: const Icon(LucideIcons.shield),
          title: const Text('Security Center'),
          onTap: () => context.go(RoutePaths.securityCenter),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Request account deactivation',
          variant: ButtonVariant.secondary,
          expand: true,
          onPressed: () => ref
              .read(profileControllerProvider.notifier)
              .requestDeactivation(hub.profile.id),
        ),
      ],
    );
  }
}
