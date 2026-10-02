import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/crm/domain/entities/crm_models.dart';
import 'package:hdhomesproject/features/crm/presentation/providers/crm_controller.dart';
import 'package:hdhomesproject/features/crm/presentation/widgets/crm_command_center_shell.dart';
import 'package:hdhomesproject/features/home/data/providers/payment_calculator_provider.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Calculator applications inside Sales, so a salesperson can open the
/// applicant and invite them without leaving the desk.
class CrmCalculatorLeadsTab extends ConsumerWidget {
  const CrmCalculatorLeadsTab({super.key, required this.snap});

  final CrmCommandCenterSnapshot snap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cmsCalculatorApplicationsProvider);
    final query = ref
        .watch(crmControllerProvider)
        .searchQuery
        .trim()
        .toLowerCase();
    final money = NumberFormat.currency(
      locale: 'en_NG',
      symbol: '₦',
      decimalDigits: 0,
    );

    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: CrmDeskColors.gold),
      ),
      error: (_, _) => const Center(
        child: Text(
          'Calculator applications could not be loaded.',
          style: TextStyle(color: CrmDeskColors.muted),
        ),
      ),
      data: (items) {
        final rows = items.where((app) {
          if (query.isEmpty) return true;
          return app.fullName.toLowerCase().contains(query) ||
              app.email.toLowerCase().contains(query) ||
              app.phone.toLowerCase().contains(query) ||
              app.city.toLowerCase().contains(query) ||
              app.planName.toLowerCase().contains(query);
        }).toList();
        if (rows.isEmpty) {
          return const Center(
            child: Text(
              'No calculator applications yet. They appear here when someone applies from the public site, Buying Tools, or Investment Tools.',
              textAlign: TextAlign.center,
              style: TextStyle(color: CrmDeskColors.muted, height: 1.4),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final app = rows[index];
            return _LeadCard(application: app, snap: snap, money: money);
          },
        );
      },
    );
  }
}

class _LeadCard extends ConsumerStatefulWidget {
  const _LeadCard({
    required this.application,
    required this.snap,
    required this.money,
  });

  final CmsCalculatorApplication application;
  final CrmCommandCenterSnapshot snap;
  final NumberFormat money;

  @override
  ConsumerState<_LeadCard> createState() => _LeadCardState();
}

class _LeadCardState extends ConsumerState<_LeadCard> {
  var _busy = false;

  Future<void> _startSale() async {
    final app = widget.application;
    setState(() => _busy = true);
    try {
      final crm = ref.read(crmServiceProvider);
      final email = app.email.trim().toLowerCase();
      final existing = widget.snap.clients
          .where((c) => (c.email ?? '').trim().toLowerCase() == email)
          .firstOrNull;
      final clientId =
          existing?.id ??
          await crm.upsertClient(
            fullName: app.fullName,
            email: app.email,
            phone: app.phone,
            whatsapp: app.preferredContact == 'whatsapp' ? app.phone : null,
            occupation: app.occupation,
            preferredLocations: app.city.isEmpty ? const [] : [app.city],
            budgetMin: app.depositAmount,
            budgetMax: app.propertyPrice,
            customerType: 'buyer',
            relationshipStatus: 'lead',
          );
      final already = widget.snap.leads.any(
        (lead) => (lead.notes ?? '').contains(app.id),
      );
      if (!already) {
        final plan = app.planName.isEmpty ? 'Payment plan' : app.planName;
        await crm.createLead(
          clientId: clientId,
          title: '$plan · ${widget.money.format(app.monthlyPayment)} / month',
          priority: 'high',
          estimatedValue: app.propertyPrice,
          conversionProbability: 25,
          notes: [
            'Calculator application ${app.id}',
            'Deposit ${widget.money.format(app.depositAmount)}',
            'Financed ${widget.money.format(app.loanAmount)}',
            '${app.durationMonths} months at ${app.interestRate}%',
            'Total repayment ${widget.money.format(app.totalRepayment)}',
            if (app.applicantMessage.isNotEmpty) app.applicantMessage,
          ].join('\n'),
        );
      }
      try {
        await ref
            .read(cmsServiceProvider)
            .updateCalculatorApplicationStatus(
              id: app.id,
              status: app.status == 'new' ? 'contacted' : app.status,
            );
      } catch (_) {}
      ref.invalidate(cmsCalculatorApplicationsProvider);
      await ref
          .read(crmControllerProvider.notifier)
          .afterMutation(
            existing == null
                ? 'Client and lead created. Invite them to the portal from this profile.'
                : 'Lead is on this client. Invite them to the portal from this profile.',
          );
      ref.read(crmControllerProvider.notifier).selectClient(clientId);
    } catch (e) {
      ref
          .read(crmControllerProvider.notifier)
          .setMessage('Could not start the sale. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.application;
    final money = widget.money;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CrmDeskColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CrmDeskColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  app.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                app.statusLabel,
                style: const TextStyle(
                  color: CrmDeskColors.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              app.email,
              if (app.phone.isNotEmpty) app.phone,
              if (app.city.isNotEmpty) app.city,
              'Prefers ${app.preferredContactLabel}',
            ].join(' · '),
            style: const TextStyle(color: CrmDeskColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            '${app.planName.isEmpty ? 'Payment plan' : app.planName} · '
            '${money.format(app.monthlyPayment)} / month · '
            'Deposit ${money.format(app.depositAmount)} · '
            '${app.durationMonths} months',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          if (app.applicantMessage.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              app.applicantMessage,
              style: const TextStyle(color: Colors.white70, height: 1.35),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _startSale,
            style: FilledButton.styleFrom(
              backgroundColor: CrmDeskColors.gold,
              foregroundColor: Colors.black,
              visualDensity: VisualDensity.compact,
            ),
            icon: Icon(
              _busy ? LucideIcons.loader : LucideIcons.userPlus,
              size: 15,
            ),
            label: Text(_busy ? 'Starting…' : 'Start sale'),
          ),
        ],
      ),
    );
  }
}
