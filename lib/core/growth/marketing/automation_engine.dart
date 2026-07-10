import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/growth/models/growth_models.dart';
import 'package:hdhomesproject/core/growth/providers/growth_cms_provider.dart';

/// Evaluates enabled automation rules against lead score (no-code studio placeholder).
final triggeredAutomationProvider = Provider.family<List<AutomationRule>, int>((ref, leadScore) {
  final rules = ref.watch(growthHubCmsProvider).automationRules;
  return rules.where((r) {
    if (!r.enabled) return false;
    if (r.trigger.contains('≥ 80') || r.trigger.contains('>= 80')) return leadScore >= 80;
    if (r.trigger.contains('milestone')) return false;
    if (r.trigger.contains('24h')) return leadScore >= 40 && leadScore < 60;
    return false;
  }).toList();
});

List<String> planLeadAutomation(int leadScore) {
  if (leadScore >= 80) {
    return ['Assign Senior Sales', 'Send WhatsApp', 'Create CRM task', 'Notify admin'];
  }
  if (leadScore >= 60) {
    return ['Assign Property Advisor', 'Send email follow-up', 'Schedule callback'];
  }
  return ['Add to nurture sequence', 'Send welcome email'];
}
