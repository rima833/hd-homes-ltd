import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/growth/analytics/journey_tracker.dart';
import 'package:hdhomesproject/core/growth/lead_scoring/smart_lead_scoring.dart';
import 'package:hdhomesproject/core/growth/personalization/visitor_profile.dart';
import 'package:hdhomesproject/features/contact/data/models/contact_content.dart';

/// Smart lead routing engine — assigns score, department, and staff (CRM placeholder).
LeadRoutingResult routeLead(LeadQualificationInput input, {String inquiryType = 'general'}) {
  var score = 35;

  if (input.budget != null && input.budget!.isNotEmpty) {
    final budget = input.budget!.toLowerCase();
    if (budget.contains('100') || budget.contains('premium') || budget.contains('luxury')) {
      score += 25;
    } else if (budget.contains('50') || budget.contains('40')) {
      score += 15;
    } else {
      score += 8;
    }
  }

  if (input.investmentInterest) score += 20;
  if (input.timeline != null && input.timeline!.toLowerCase().contains('immediate')) score += 12;
  if (input.location != null && input.location!.toLowerCase().contains('lekki')) score += 5;

  final department = _resolveDepartment(input, inquiryType);
  final assignedTo = _assignStaff(department, score);
  final priority = _priority(score, input.priority);

  return LeadRoutingResult(
    score: score.clamp(0, 100),
    department: department,
    assignedTo: assignedTo,
    priority: priority,
    pipelineStage: CrmPipelineStage.newLead,
    summary:
        'Lead scored $score/100 → $department → $assignedTo (${priority.name} priority). '
        'CRM record, timeline entry, and follow-up task created automatically.',
  );
}

String _resolveDepartment(LeadQualificationInput input, String inquiryType) {
  if (input.department != null) {
    return switch (input.department!) {
      DepartmentId.sales => 'Sales',
      DepartmentId.investorRelations => 'Investor Relations',
      DepartmentId.construction => 'Construction',
      DepartmentId.legal => 'Legal & Compliance',
      DepartmentId.finance => 'Finance & Mortgages',
      DepartmentId.propertyManagement => 'Property Management',
      DepartmentId.customerSupport => 'Customer Support',
      DepartmentId.marketing => 'Marketing',
      DepartmentId.careers => 'Careers & HR',
      DepartmentId.general => 'General Inquiry',
    };
  }

  return switch (inquiryType) {
    'inspection' => 'Sales',
    'consultation' => input.investmentInterest ? 'Investor Relations' : 'Sales',
    'callback' => 'Customer Support',
    'support' => 'Customer Support',
    'careers' => 'Careers & HR',
    'partnership' => 'Business Development',
    'investor' => 'Investor Relations',
    _ when input.investmentInterest => 'Investor Relations',
    _ => 'Sales',
  };
}

String _assignStaff(String department, int score) {
  if (score >= 80) {
    return switch (department) {
      'Sales' => 'Senior Sales Executive',
      'Investor Relations' => 'Head of Investor Relations',
      _ => 'Department Manager',
    };
  }
  if (score >= 60) {
    return switch (department) {
      'Sales' => 'Property Advisor',
      'Investor Relations' => 'Investment Analyst',
      'Construction' => 'Site Manager',
      _ => 'Team Lead',
    };
  }
  return switch (department) {
    'Sales' => 'Sales Associate',
    'Customer Support' => 'Support Agent',
    _ => 'Front Desk',
  };
}

LeadPriority _priority(int score, LeadPriority requested) {
  if (requested == LeadPriority.vip) return LeadPriority.vip;
  if (score >= 75) return LeadPriority.high;
  if (score >= 50) return LeadPriority.normal;
  return LeadPriority.low;
}

String generateVisitorPassCode() =>
    'HD-${DateTime.now().millisecondsSinceEpoch.remainder(1000000).toString().padLeft(6, '0')}';

final submittedLeadsProvider =
    StateProvider<List<SubmittedLead>>((ref) => []);

SubmittedLead submitLead(
  WidgetRef ref, {
  required String type,
  required LeadQualificationInput qualification,
  bool generatePass = false,
}) {
  final routing = routeLead(qualification, inquiryType: type);
  final profile = ref.read(visitorProfileProvider);
  final smart = computeSmartLeadScore(baseRouting: routing, profile: profile);
  final lead = SubmittedLead(
    id: 'lead-${DateTime.now().millisecondsSinceEpoch}',
    type: type,
    routing: routing,
    submittedAt: DateTime.now(),
    visitorPassCode: generatePass ? generateVisitorPassCode() : null,
  );
  ref.read(submittedLeadsProvider.notifier).update((state) => [lead, ...state]);
  trackGrowthLeadSubmitted(ref, lead, smart);
  return lead;
}
