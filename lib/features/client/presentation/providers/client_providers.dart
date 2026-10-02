import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/auth/models/auth_session_snapshot.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/communication_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/client/domain/entities/client_models.dart';
import 'package:hdhomesproject/features/client/domain/entities/client_payment_engine_models.dart';
import 'package:hdhomesproject/features/client/domain/services/client_payment_engine_service.dart';
import 'package:hdhomesproject/features/client/domain/services/client_service.dart';

final clientMessagesTickProvider = StateProvider<int>((ref) => 0);
final clientTicketMessagesTickProvider = StateProvider<int>((ref) => 0);

double computeClientAccountCompletion(
  AuthSessionSnapshot session,
  ClientDashboardSnapshot snap,
) {
  var score = 0.0;
  final profile = session.profile;

  if (profile?.firstName?.isNotEmpty == true) score += 15;
  if (profile?.lastName?.isNotEmpty == true) score += 10;
  if (profile?.phone?.isNotEmpty == true) score += 15;
  if (session.emailConfirmed) score += 15;
  if (profile?.avatarUrl?.isNotEmpty == true ||
      profile?.address?.isNotEmpty == true) {
    score += 10;
  }
  if (snap.propertiesCount > 0) score += 20;
  if (snap.recentDocuments.isNotEmpty) score += 15;

  return score.clamp(0, 100);
}

final clientServiceProvider = Provider<ClientService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return ClientService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final clientRecordProvider = FutureProvider<ClientRecord?>((ref) async {
  final userId = ref.watch(identitySessionProvider).userId;
  if (userId == null) return null;
  return ref.watch(clientServiceProvider).ensureClient();
});

final clientDashboardProvider =
    FutureProvider<ClientDashboardSnapshot?>((ref) async {
  final session = ref.watch(identitySessionProvider);
  final userId = session.userId;
  if (userId == null) return null;
  final unread =
      ref.watch(notificationCenterProvider).valueOrNull?.unreadCount ?? 0;
  final name = session.profile?.firstName ?? session.profile?.email ?? 'Client';
  final snap = await ref.watch(clientServiceProvider).loadDashboard(
        displayName: name,
        unreadNotifications: unread,
      );
  return ClientDashboardSnapshot(
    client: snap.client,
    displayName: snap.displayName,
    propertiesCount: snap.propertiesCount,
    outstandingBalance: snap.outstandingBalance,
    totalPaid: snap.totalPaid,
    upcomingInspections: snap.upcomingInspections,
    unreadNotifications: snap.unreadNotifications,
    accountCompletionPct: computeClientAccountCompletion(session, snap),
    properties: snap.properties,
    recentTimeline: snap.recentTimeline,
    recentDocuments: snap.recentDocuments,
    upcomingInstallments: snap.upcomingInstallments,
    constructionProgress: snap.constructionProgress,
    paymentHistory: snap.paymentHistory,
    loadedAt: snap.loadedAt,
  );
});

final clientPropertiesProvider =
    FutureProvider<List<ClientProperty>>((ref) async {
  final record = await ref.watch(clientRecordProvider.future);
  if (record == null) return [];
  return ref.watch(clientServiceProvider).listProperties(record.id);
});

final clientSavedPropertiesProvider =
    FutureProvider<List<ClientProperty>>((ref) async {
  final userId = ref.watch(identitySessionProvider).userId;
  if (userId == null) return [];
  return ref.watch(clientServiceProvider).listSavedProperties();
});

final clientSavedPropertyIdsProvider = FutureProvider<Set<String>>((ref) async {
  final saved = await ref.watch(clientSavedPropertiesProvider.future);
  return saved.map((p) => p.propertyId).toSet();
});

final clientPaymentsProvider = FutureProvider<ClientPaymentsBundle>((ref) async {
  final record = await ref.watch(clientRecordProvider.future);
  if (record == null) return const ClientPaymentsBundle();
  final service = ref.watch(clientServiceProvider);
  final payments = await service.listPayments(record.id);
  final installments = await service.listInstallments(record.id);

  ClientPaymentSummary? summary;
  try {
    final configured = ref.watch(supabaseConfiguredProvider);
    summary = await ClientPaymentEngineService(
      client: configured ? ref.watch(supabaseClientProvider) : null,
    ).fetchPaymentSummary();
  } catch (_) {
    // Prefer server summary when available; fall back to local aggregates.
  }

  return ClientPaymentsBundle(
    payments: payments,
    installments: installments,
    summary: summary,
  );
});

class ClientPaymentsBundle {
  const ClientPaymentsBundle({
    this.payments = const [],
    this.installments = const [],
    this.summary,
  });
  final List<ClientPayment> payments;
  final List<ClientInstallment> installments;
  final ClientPaymentSummary? summary;

  double get outstanding {
    final s = summary;
    if (s != null) return s.outstanding;
    return installments
        .where((i) => i.isPayable)
        .fold<double>(0, (sum, i) => sum + i.payableAmount);
  }

  double get totalPaid {
    final s = summary;
    if (s != null) return s.totalPaid;
    return payments
        .where((p) => p.status == 'completed' || p.status == 'paid')
        .fold<double>(0, (sum, p) => sum + p.amount);
  }

  double get propertyValue => summary?.propertyValue ?? 0;

  ClientNextPayment? get nextPayment => summary?.nextPayment;

  double? get paidProgress {
    final s = summary?.paidProgress;
    if (s != null) return s;
    final denom = totalPaid + outstanding;
    if (denom <= 0) return null;
    return (totalPaid / denom).clamp(0.0, 1.0);
  }
}

final clientDocumentsProvider =
    FutureProvider<List<ClientDocument>>((ref) async {
  final record = await ref.watch(clientRecordProvider.future);
  if (record == null) return [];
  return ref.watch(clientServiceProvider).listDocuments(record.id);
});

final clientConstructionProvider =
    FutureProvider<List<ClientConstructionUpdate>>((ref) async {
  final record = await ref.watch(clientRecordProvider.future);
  if (record == null) return [];
  return ref.watch(clientServiceProvider).listConstructionUpdates(record.id);
});

final clientInspectionsProvider =
    FutureProvider<List<ClientInspection>>((ref) async {
  final record = await ref.watch(clientRecordProvider.future);
  if (record == null) return [];
  return ref.watch(clientServiceProvider).listInspections(record.id);
});

final clientConversationsProvider =
    FutureProvider<List<ClientConversation>>((ref) async {
  ref.watch(clientMessagesTickProvider);
  final record = await ref.watch(clientRecordProvider.future);
  if (record == null) return [];
  return ref.watch(clientServiceProvider).listConversations(record.id);
});

final staffClientConversationsProvider =
    FutureProvider<List<ClientConversation>>((ref) async {
  ref.watch(clientMessagesTickProvider);
  final userId = ref.watch(identitySessionProvider).userId;
  if (userId == null) return [];
  return ref.watch(clientServiceProvider).listStaffConversations();
});

final clientConversationDetailProvider =
    FutureProvider.family<ClientConversation?, String>((ref, conversationId) async {
  ref.watch(clientMessagesTickProvider);
  return ref.watch(clientServiceProvider).getConversation(conversationId);
});

final clientConversationMessagesProvider =
    FutureProvider.family<List<ClientMessage>, String>((
  ref,
  conversationId,
) async {
  ref.watch(clientMessagesTickProvider);
  final userId = ref.watch(identitySessionProvider).userId;
  if (userId == null) return [];
  return ref.watch(clientServiceProvider).listMessages(
        conversationId,
        userId: userId,
      );
});

final clientTicketsProvider =
    FutureProvider<List<ClientSupportTicket>>((ref) async {
  ref.watch(clientTicketMessagesTickProvider);
  final userId = ref.watch(identitySessionProvider).userId;
  if (userId == null) return [];
  return ref.watch(clientServiceProvider).listTickets();
});

final clientTicketMessagesProvider =
    FutureProvider.family<List<ClientTicketMessage>, String>((ref, ticketId) async {
  ref.watch(clientTicketMessagesTickProvider);
  final userId = ref.watch(identitySessionProvider).userId;
  if (userId == null) return [];
  return ref.watch(clientServiceProvider).listTicketMessages(ticketId);
});

final clientApplicationsProvider =
    FutureProvider<List<ClientPropertyApplication>>((ref) async {
  final record = await ref.watch(clientRecordProvider.future);
  if (record == null) return [];
  return ref.watch(clientServiceProvider).listApplications(record.id);
});

final clientApplicationDetailProvider =
    FutureProvider.family<ClientPropertyApplication?, String>((ref, applicationId) async {
  final record = await ref.watch(clientRecordProvider.future);
  if (record == null) return null;
  return ref.watch(clientServiceProvider).getApplication(
        clientId: record.id,
        applicationId: applicationId,
      );
});

final clientApplicationDocumentsProvider =
    FutureProvider.family<List<ClientDocument>, String>((ref, applicationId) async {
  final record = await ref.watch(clientRecordProvider.future);
  if (record == null) return [];
  return ref.watch(clientServiceProvider).listApplicationDocuments(
        clientId: record.id,
        applicationId: applicationId,
      );
});

final clientApplicationTimelineProvider =
    FutureProvider.family<List<ClientTimelineEvent>, String>((ref, applicationId) async {
  final record = await ref.watch(clientRecordProvider.future);
  if (record == null) return [];
  return ref.watch(clientServiceProvider).listApplicationTimeline(
        clientId: record.id,
        applicationId: applicationId,
      );
});

final clientApplicationPropertyOptionsProvider =
    FutureProvider<List<ClientApplicationPropertyOption>>((ref) async {
  final userId = ref.watch(identitySessionProvider).userId;
  if (userId == null) return [];
  return ref.watch(clientServiceProvider).listApplicationPropertyOptions();
});

final applicationPaymentPlansProvider =
    FutureProvider.family<List<ApplicationPaymentPlan>, String?>((ref, propertyId) async {
  final userId = ref.watch(identitySessionProvider).userId;
  if (userId == null) return [];
  return ref
      .watch(clientServiceProvider)
      .listApplicationPaymentPlans(propertyId: propertyId);
});

final applicationRequiredDocumentTypesProvider =
    FutureProvider<List<ApplicationRequiredDocumentType>>((ref) async {
  final userId = ref.watch(identitySessionProvider).userId;
  if (userId == null) return [];
  return ref.watch(clientServiceProvider).listRequiredApplicationDocumentTypes();
});

final clientReferralsProvider =
    FutureProvider<ClientReferralSummary>((ref) async {
  final record = await ref.watch(clientRecordProvider.future);
  if (record == null) return const ClientReferralSummary();
  return ref.watch(clientServiceProvider).loadReferrals(record.id);
});

final clientPreferencesProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final record = await ref.watch(clientRecordProvider.future);
  if (record == null) return {};
  return ref.watch(clientServiceProvider).loadPreferences(record.id);
});

final clientPropertyDetailProvider =
    FutureProvider.family<ClientProperty?, String>((ref, propertyId) async {
  final record = await ref.watch(clientRecordProvider.future);
  if (record == null) return null;
  return ref.watch(clientServiceProvider).getProperty(record.id, propertyId);
});
