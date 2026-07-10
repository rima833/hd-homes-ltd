import 'package:hdhomesproject/core/growth/models/growth_models.dart';
import 'package:hdhomesproject/features/contact/data/models/contact_content.dart';

/// Combines qualification rules with behavioral signals for smart lead scoring.
SmartLeadScore computeSmartLeadScore({
  required LeadRoutingResult baseRouting,
  required VisitorProfile profile,
}) {
  var score = baseRouting.score;

  score += profile.propertyIdsViewed.length * 3;
  score += profile.pagesViewed.length.clamp(0, 15);
  if (profile.downloadCount > 0) score += 10;
  if (profile.chatInteractions > 0) score += 5;
  if (profile.searchQueries.length >= 3) score += 8;
  if (profile.utmSource != null) score += 3;

  final clamped = score.clamp(0, 100);
  final temperature = _temperature(clamped);
  final channel = _channel(clamped, profile);
  final contactTime = clamped >= 80 ? 'Within 1 hour' : clamped >= 60 ? 'Same business day' : 'Within 48 hours';
  final executive = baseRouting.assignedTo;
  final action = _followUp(clamped, temperature);

  return SmartLeadScore(
    score: clamped,
    temperature: temperature,
    recommendedChannel: channel,
    recommendedContactTime: contactTime,
    recommendedExecutive: executive,
    followUpAction: action,
  );
}

LeadTemperature _temperature(int score) {
  if (score >= 90) return LeadTemperature.readyToBuy;
  if (score >= 75) return LeadTemperature.qualified;
  if (score >= 55) return LeadTemperature.hot;
  if (score >= 35) return LeadTemperature.warm;
  return LeadTemperature.cold;
}

String _channel(int score, VisitorProfile profile) {
  if (score >= 80) return 'WhatsApp + Phone';
  if (profile.chatInteractions > 0) return 'Live chat follow-up';
  if (score >= 50) return 'Email + Phone';
  return 'Email';
}

String _followUp(int score, LeadTemperature temp) {
  return switch (temp) {
    LeadTemperature.readyToBuy => 'Immediate personal outreach — schedule inspection today',
    LeadTemperature.qualified => 'Send personalized property shortlist and book consultation',
    LeadTemperature.hot => 'Assign property advisor and share payment plan options',
    LeadTemperature.warm => 'Add to nurture sequence with weekly property alerts',
    LeadTemperature.cold => 'Welcome email + educational content drip',
  };
}

CustomerJourneyStage inferJourneyStage({
  required VisitorProfile profile,
  required int leadCount,
  required bool isAuthenticated,
}) {
  if (leadCount > 0 && profile.propertyIdsViewed.length >= 3) {
    return CustomerJourneyStage.propertyInquiry;
  }
  if (leadCount > 0) return CustomerJourneyStage.qualifiedLead;
  if (isAuthenticated) return CustomerJourneyStage.registeredUser;
  return CustomerJourneyStage.anonymousVisitor;
}
