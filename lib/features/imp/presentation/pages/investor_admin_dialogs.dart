import 'package:flutter/material.dart';
import 'package:hdhomesproject/features/imp/domain/entities/imp_models.dart';

class InvestorFormValue {
  const InvestorFormValue({
    required this.fullName,
    required this.investorType,
    required this.lifecycleStatus,
    required this.riskLevel,
    required this.preferredCurrency,
    this.email,
    this.phone,
    this.company,
    this.nationality,
  });

  final String fullName;
  final String? email;
  final String? phone;
  final String? company;
  final String? nationality;
  final InvestorType investorType;
  final InvestorLifecycleStatus lifecycleStatus;
  final RiskLevel riskLevel;
  final String preferredCurrency;
}

class OpportunityFormValue {
  const OpportunityFormValue({
    required this.title,
    required this.status,
    required this.targetRaise,
    required this.amountRaised,
    required this.currency,
    required this.riskLevel,
    this.description,
    this.minTicket,
    this.maxTicket,
    this.projectedReturnPct,
  });

  final String title;
  final String? description;
  final OpportunityStatus status;
  final double targetRaise;
  final double amountRaised;
  final double? minTicket;
  final double? maxTicket;
  final double? projectedReturnPct;
  final String currency;
  final RiskLevel riskLevel;
}

class DistributionFormValue {
  const DistributionFormValue({
    required this.investorId,
    required this.amount,
    required this.status,
    required this.distributionType,
    required this.currency,
    this.opportunityId,
    this.scheduledAt,
    this.reference,
  });

  final String investorId;
  final String? opportunityId;
  final double amount;
  final DistributionStatus status;
  final String distributionType;
  final String currency;
  final DateTime? scheduledAt;
  final String? reference;
}

class CommitmentFormValue {
  const CommitmentFormValue({
    required this.investorId,
    required this.opportunityId,
    required this.amount,
    required this.currency,
    required this.status,
    this.notes,
  });

  final String investorId;
  final String opportunityId;
  final double amount;
  final String currency;
  final String status;
  final String? notes;
}

String? _optional(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

Widget _dialogFrame({
  required BuildContext context,
  required String title,
  required GlobalKey<FormState> formKey,
  required List<Widget> fields,
  required VoidCallback onSave,
}) {
  final width = MediaQuery.sizeOf(context).width;
  return AlertDialog(
    title: Text(title),
    content: SizedBox(
      width: width < 600 ? width : 520,
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children:
                fields
                    .expand((field) => [field, const SizedBox(height: 12)])
                    .toList()
                  ..removeLast(),
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: onSave, child: const Text('Save')),
    ],
  );
}

Future<InvestorFormValue?> showInvestorFormDialog({
  required BuildContext context,
  ImpInvestor? investor,
}) {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(text: investor?.fullName);
  final email = TextEditingController(text: investor?.email);
  final phone = TextEditingController(text: investor?.phone);
  final company = TextEditingController(text: investor?.company);
  final nationality = TextEditingController(text: investor?.nationality);
  final currency = TextEditingController(
    text: investor?.preferredCurrency ?? 'NGN',
  );
  var type = investor?.investorType ?? InvestorType.individual;
  var lifecycle = investor?.lifecycleStatus ?? InvestorLifecycleStatus.prospect;
  var risk = investor?.riskLevel ?? RiskLevel.moderate;

  return showDialog<InvestorFormValue>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => _dialogFrame(
        context: context,
        title: investor == null ? 'Create investor' : 'Edit investor',
        formKey: formKey,
        onSave: () {
          if (!formKey.currentState!.validate()) return;
          Navigator.of(dialogContext).pop(
            InvestorFormValue(
              fullName: name.text.trim(),
              email: _optional(email.text),
              phone: _optional(phone.text),
              company: _optional(company.text),
              nationality: _optional(nationality.text),
              investorType: type,
              lifecycleStatus: lifecycle,
              riskLevel: risk,
              preferredCurrency: currency.text.trim().toUpperCase(),
            ),
          );
        },
        fields: [
          TextFormField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Full name *'),
            textCapitalization: TextCapitalization.words,
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Required' : null,
          ),
          TextFormField(
            controller: email,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isNotEmpty && !text.contains('@')) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          TextFormField(
            controller: phone,
            decoration: const InputDecoration(labelText: 'Phone'),
            keyboardType: TextInputType.phone,
          ),
          TextFormField(
            controller: company,
            decoration: const InputDecoration(labelText: 'Company'),
          ),
          TextFormField(
            controller: nationality,
            decoration: const InputDecoration(labelText: 'Nationality'),
          ),
          DropdownButtonFormField<InvestorType>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Investor type'),
            items: InvestorType.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(),
            onChanged: (value) => setState(() => type = value!),
          ),
          DropdownButtonFormField<InvestorLifecycleStatus>(
            initialValue: lifecycle,
            decoration: const InputDecoration(labelText: 'Lifecycle status'),
            items: InvestorLifecycleStatus.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(),
            onChanged: (value) => setState(() => lifecycle = value!),
          ),
          DropdownButtonFormField<RiskLevel>(
            initialValue: risk,
            decoration: const InputDecoration(labelText: 'Risk level'),
            items: RiskLevel.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(),
            onChanged: (value) => setState(() => risk = value!),
          ),
          TextFormField(
            controller: currency,
            decoration: const InputDecoration(
              labelText: 'Preferred currency *',
            ),
            textCapitalization: TextCapitalization.characters,
            maxLength: 3,
            validator: (value) => value == null || value.trim().length != 3
                ? 'Enter a 3-letter currency code'
                : null,
          ),
        ],
      ),
    ),
  );
}

double? _number(String? value) => double.tryParse((value ?? '').trim());

String? _requiredNonNegative(String? value) {
  final number = _number(value);
  if (number == null) return 'Enter a number';
  if (number < 0) return 'Must be zero or greater';
  return null;
}

String? _optionalNonNegative(String? value) {
  if ((value ?? '').trim().isEmpty) return null;
  return _requiredNonNegative(value);
}

Future<OpportunityFormValue?> showOpportunityFormDialog({
  required BuildContext context,
  ImpOpportunity? opportunity,
}) {
  final formKey = GlobalKey<FormState>();
  final title = TextEditingController(text: opportunity?.title);
  final description = TextEditingController(text: opportunity?.description);
  final target = TextEditingController(
    text: opportunity?.targetRaise.toString(),
  );
  final raised = TextEditingController(
    text: opportunity?.amountRaised.toString(),
  );
  final minTicket = TextEditingController(
    text: opportunity?.minTicket?.toString(),
  );
  final maxTicket = TextEditingController(
    text: opportunity?.maxTicket?.toString(),
  );
  final returnPct = TextEditingController(
    text: opportunity?.projectedReturnPct?.toString(),
  );
  final currency = TextEditingController(text: opportunity?.currency ?? 'NGN');
  var status = opportunity?.status ?? OpportunityStatus.open;
  var risk = opportunity?.riskLevel ?? RiskLevel.moderate;

  return showDialog<OpportunityFormValue>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => _dialogFrame(
        context: context,
        title: opportunity == null ? 'Create opportunity' : 'Edit opportunity',
        formKey: formKey,
        onSave: () {
          if (!formKey.currentState!.validate()) return;
          final min = _number(minTicket.text);
          final max = _number(maxTicket.text);
          if (min != null && max != null && max < min) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Maximum ticket cannot be below minimum ticket'),
              ),
            );
            return;
          }
          Navigator.of(dialogContext).pop(
            OpportunityFormValue(
              title: title.text.trim(),
              description: _optional(description.text),
              status: status,
              targetRaise: _number(target.text)!,
              amountRaised: _number(raised.text)!,
              minTicket: min,
              maxTicket: max,
              projectedReturnPct: _number(returnPct.text),
              currency: currency.text.trim().toUpperCase(),
              riskLevel: risk,
            ),
          );
        },
        fields: [
          TextFormField(
            controller: title,
            decoration: const InputDecoration(labelText: 'Title *'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Required' : null,
          ),
          TextFormField(
            controller: description,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 3,
          ),
          DropdownButtonFormField<OpportunityStatus>(
            initialValue: status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: OpportunityStatus.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(),
            onChanged: (value) => setState(() => status = value!),
          ),
          TextFormField(
            controller: target,
            decoration: const InputDecoration(labelText: 'Target raise *'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: _requiredNonNegative,
          ),
          TextFormField(
            controller: raised,
            decoration: const InputDecoration(labelText: 'Amount raised *'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: _requiredNonNegative,
          ),
          TextFormField(
            controller: minTicket,
            decoration: const InputDecoration(labelText: 'Minimum ticket'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: _optionalNonNegative,
          ),
          TextFormField(
            controller: maxTicket,
            decoration: const InputDecoration(labelText: 'Maximum ticket'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: _optionalNonNegative,
          ),
          TextFormField(
            controller: returnPct,
            decoration: const InputDecoration(
              labelText: 'Projected return (%)',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: _optionalNonNegative,
          ),
          TextFormField(
            controller: currency,
            decoration: const InputDecoration(labelText: 'Currency *'),
            maxLength: 3,
            textCapitalization: TextCapitalization.characters,
            validator: (value) => value == null || value.trim().length != 3
                ? 'Enter a 3-letter currency code'
                : null,
          ),
          DropdownButtonFormField<RiskLevel>(
            initialValue: risk,
            decoration: const InputDecoration(labelText: 'Risk level'),
            items: RiskLevel.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(),
            onChanged: (value) => setState(() => risk = value!),
          ),
        ],
      ),
    ),
  );
}

Future<CommitmentFormValue?> showCommitmentFormDialog({
  required BuildContext context,
  required List<ImpInvestor> investors,
  required List<ImpOpportunity> opportunities,
  ImpCommitment? commitment,
}) {
  if (investors.isEmpty || opportunities.isEmpty) {
    return Future.value(null);
  }
  final formKey = GlobalKey<FormState>();
  final amount = TextEditingController(text: commitment?.amount.toString());
  final currency = TextEditingController(text: commitment?.currency ?? 'NGN');
  final notes = TextEditingController();
  var investorId = commitment?.investorId ?? investors.first.id;
  var opportunityId = commitment?.opportunityId ?? opportunities.first.id;
  var status = commitment?.status ?? 'pending';
  const statuses = [
    'pending',
    'reserved',
    'confirmed',
    'funded',
    'cancelled',
    'refunded',
  ];

  return showDialog<CommitmentFormValue>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => _dialogFrame(
        context: context,
        title: commitment == null ? 'Record commitment' : 'Edit commitment',
        formKey: formKey,
        onSave: () {
          if (!formKey.currentState!.validate()) return;
          Navigator.of(dialogContext).pop(
            CommitmentFormValue(
              investorId: investorId,
              opportunityId: opportunityId,
              amount: _number(amount.text)!,
              currency: currency.text.trim().toUpperCase(),
              status: status,
              notes: _optional(notes.text),
            ),
          );
        },
        fields: [
          DropdownButtonFormField<String>(
            initialValue: investorId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Investor *'),
            items: investors
                .map(
                  (value) => DropdownMenuItem(
                    value: value.id,
                    child: Text(
                      value.fullName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => investorId = value!),
          ),
          DropdownButtonFormField<String>(
            initialValue: opportunityId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Opportunity *'),
            items: opportunities
                .map(
                  (value) => DropdownMenuItem(
                    value: value.id,
                    child: Text(
                      value.title,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => opportunityId = value!),
          ),
          TextFormField(
            controller: amount,
            decoration: const InputDecoration(labelText: 'Amount *'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              final number = _number(value);
              if (number == null) return 'Enter a number';
              return number <= 0 ? 'Must be greater than zero' : null;
            },
          ),
          DropdownButtonFormField<String>(
            initialValue: status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: statuses
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(
                      '${value[0].toUpperCase()}${value.substring(1)}',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => status = value!),
          ),
          TextFormField(
            controller: currency,
            decoration: const InputDecoration(labelText: 'Currency *'),
            maxLength: 3,
            textCapitalization: TextCapitalization.characters,
            validator: (value) => value == null || value.trim().length != 3
                ? 'Enter a 3-letter currency code'
                : null,
          ),
          TextFormField(
            controller: notes,
            decoration: const InputDecoration(labelText: 'Notes'),
            maxLines: 2,
          ),
        ],
      ),
    ),
  );
}

Future<DistributionFormValue?> showDistributionFormDialog({
  required BuildContext context,
  required List<ImpInvestor> investors,
  required List<ImpOpportunity> opportunities,
  ImpDistribution? distribution,
}) {
  if (investors.isEmpty) return Future.value(null);
  final formKey = GlobalKey<FormState>();
  final amount = TextEditingController(text: distribution?.amount.toString());
  final type = TextEditingController(
    text: distribution?.distributionType ?? 'dividend',
  );
  final currency = TextEditingController(text: distribution?.currency ?? 'NGN');
  final reference = TextEditingController(text: distribution?.reference);
  var investorId = distribution?.investorId ?? investors.first.id;
  String? opportunityId;
  if (distribution?.opportunityTitle != null) {
    for (final opportunity in opportunities) {
      if (opportunity.title == distribution!.opportunityTitle) {
        opportunityId = opportunity.id;
        break;
      }
    }
  }
  var status = distribution?.status ?? DistributionStatus.scheduled;
  var scheduledAt = distribution?.scheduledAt;

  return showDialog<DistributionFormValue>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => _dialogFrame(
        context: context,
        title: distribution == null
            ? 'Schedule distribution'
            : 'Edit distribution',
        formKey: formKey,
        onSave: () {
          if (!formKey.currentState!.validate()) return;
          Navigator.of(dialogContext).pop(
            DistributionFormValue(
              investorId: investorId,
              opportunityId: opportunityId,
              amount: _number(amount.text)!,
              status: status,
              distributionType: type.text.trim(),
              currency: currency.text.trim().toUpperCase(),
              scheduledAt: scheduledAt,
              reference: _optional(reference.text),
            ),
          );
        },
        fields: [
          DropdownButtonFormField<String>(
            initialValue: investorId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Investor *'),
            items: investors
                .map(
                  (value) => DropdownMenuItem(
                    value: value.id,
                    child: Text(
                      value.fullName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => investorId = value!),
          ),
          DropdownButtonFormField<String?>(
            initialValue: opportunityId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Opportunity'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('No linked opportunity'),
              ),
              ...opportunities.map(
                (value) => DropdownMenuItem<String?>(
                  value: value.id,
                  child: Text(value.title, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (value) => setState(() => opportunityId = value),
          ),
          TextFormField(
            controller: amount,
            decoration: const InputDecoration(labelText: 'Amount *'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              final number = _number(value);
              if (number == null) return 'Enter a number';
              return number <= 0 ? 'Must be greater than zero' : null;
            },
          ),
          DropdownButtonFormField<DistributionStatus>(
            initialValue: status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: DistributionStatus.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(),
            onChanged: (value) => setState(() => status = value!),
          ),
          TextFormField(
            controller: type,
            decoration: const InputDecoration(labelText: 'Distribution type *'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Required' : null,
          ),
          TextFormField(
            controller: currency,
            decoration: const InputDecoration(labelText: 'Currency *'),
            maxLength: 3,
            textCapitalization: TextCapitalization.characters,
            validator: (value) => value == null || value.trim().length != 3
                ? 'Enter a 3-letter currency code'
                : null,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Scheduled date'),
            subtitle: Text(
              scheduledAt == null
                  ? 'Not set'
                  : MaterialLocalizations.of(
                      context,
                    ).formatMediumDate(scheduledAt!),
            ),
            trailing: Wrap(
              children: [
                if (scheduledAt != null)
                  IconButton(
                    tooltip: 'Clear date',
                    onPressed: () => setState(() => scheduledAt = null),
                    icon: const Icon(Icons.clear),
                  ),
                IconButton(
                  tooltip: 'Choose date',
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      initialDate: scheduledAt ?? DateTime.now(),
                    );
                    if (picked != null) setState(() => scheduledAt = picked);
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                ),
              ],
            ),
          ),
          TextFormField(
            controller: reference,
            decoration: const InputDecoration(labelText: 'Reference'),
          ),
        ],
      ),
    ),
  );
}
