import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/investor/domain/entities/investor_models.dart';
import 'package:hdhomesproject/features/investor/domain/services/investor_service.dart';

/// Bumped when conversation / message tables change so open threads refresh.
final investorMessagesTickProvider = StateProvider<int>((ref) => 0);

/// Bumped when ticket tables change (support live status).
final investorTicketsTickProvider = StateProvider<int>((ref) => 0);

final investorServiceProvider = Provider<InvestorService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return InvestorService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final investorRecordProvider = FutureProvider<InvestorRecord?>((ref) async {
  final userId = ref.watch(identitySessionProvider).userId;
  if (userId == null) return null;
  return ref.watch(investorServiceProvider).ensureInvestor();
});

final investorUnreadCountProvider = FutureProvider<int>((ref) async {
  final record = await ref.watch(investorRecordProvider.future);
  if (record == null) return 0;
  final notifications =
      await ref.watch(investorServiceProvider).listNotifications(record.id);
  return notifications.where((n) => !n.isRead).length;
});

final investorDashboardProvider =
    FutureProvider<InvestorDashboardSnapshot?>((ref) async {
  final session = ref.watch(identitySessionProvider);
  final userId = session.userId;
  if (userId == null) return null;
  final unread = await ref.watch(investorUnreadCountProvider.future);
  final name =
      session.profile?.firstName ?? session.profile?.email ?? 'Investor';
  return ref.watch(investorServiceProvider).loadDashboard(
        displayName: name,
        unreadNotifications: unread,
      );
});

final investorHoldingsProvider =
    FutureProvider<List<InvestorHolding>>((ref) async {
  final record = await ref.watch(investorRecordProvider.future);
  if (record == null) return [];
  return ref.watch(investorServiceProvider).listHoldings(record.id);
});

final investorHoldingDetailProvider =
    FutureProvider.family<InvestorHoldingDetail?, String>((ref, holdingId) async {
  final record = await ref.watch(investorRecordProvider.future);
  if (record == null) return null;
  return ref.watch(investorServiceProvider).loadHoldingDetail(record.id, holdingId);
});

final investorPaymentsProvider =
    FutureProvider<InvestorPaymentsBundle>((ref) async {
  final record = await ref.watch(investorRecordProvider.future);
  if (record == null) return const InvestorPaymentsBundle();
  final service = ref.watch(investorServiceProvider);
  final distributions = await service.listDistributions(record.id);
  final wallets = await service.listWallet(record.id);
  final intents = await service.listPaymentIntents(record.id);
  final receiving = await service.listReceivingAccounts();
  final settled = await service.listSettledPayments(record.id);
  final receipts = await service.listPaymentReceipts(record.id);
  final holdings = await service.listHoldings(record.id);
  return InvestorPaymentsBundle(
    distributions: distributions,
    wallets: wallets,
    paymentIntents: intents,
    receivingAccounts: receiving,
    settledPayments: settled,
    receipts: receipts,
    holdings: holdings,
  );
});

class InvestorPaymentsBundle {
  const InvestorPaymentsBundle({
    this.distributions = const [],
    this.wallets = const [],
    this.paymentIntents = const [],
    this.receivingAccounts = const [],
    this.settledPayments = const [],
    this.receipts = const [],
    this.holdings = const [],
  });

  final List<InvestorDistribution> distributions;
  final List<InvestorWallet> wallets;
  final List<InvestorPaymentIntent> paymentIntents;
  final List<InvestmentReceivingAccount> receivingAccounts;
  final List<InvestorSettledPayment> settledPayments;
  final List<InvestorPaymentReceipt> receipts;
  final List<InvestorHolding> holdings;

  double get totalPaid => distributions
      .where((d) => d.status == 'paid')
      .fold<double>(0, (s, d) => s + d.amount);

  double get totalScheduled => distributions
      .where((d) => d.status == 'scheduled' || d.status == 'processing')
      .fold<double>(0, (s, d) => s + d.amount);

  double get outstandingIntents => paymentIntents
      .where((i) => i.isAwaitingVerification)
      .fold<double>(0, (s, i) => s + i.amount);

  InvestorWallet? get primaryWallet =>
      wallets.isNotEmpty ? wallets.first : null;

  InvestmentReceivingAccount? get primaryReceivingAccount {
    for (final a in receivingAccounts) {
      if (a.isPrimary) return a;
    }
    return receivingAccounts.isNotEmpty ? receivingAccounts.first : null;
  }
}

final investorDocumentsProvider =
    FutureProvider<List<InvestorDocument>>((ref) async {
  final record = await ref.watch(investorRecordProvider.future);
  if (record == null) return [];
  return ref.watch(investorServiceProvider).listDocuments(record.id);
});

final investorReportsProvider =
    FutureProvider<InvestorReportsBundle>((ref) async {
  final record = await ref.watch(investorRecordProvider.future);
  if (record == null) return const InvestorReportsBundle();
  final service = ref.watch(investorServiceProvider);
  final reports = await service.listReports(record.id);
  final statements = await service.listStatements(record.id);
  return InvestorReportsBundle(reports: reports, statements: statements);
});

class InvestorReportsBundle {
  const InvestorReportsBundle({
    this.reports = const [],
    this.statements = const [],
  });

  final List<InvestorReport> reports;
  final List<InvestorStatement> statements;
}

final investorPerformanceProvider =
    FutureProvider<List<InvestorPerformance>>((ref) async {
  final record = await ref.watch(investorRecordProvider.future);
  if (record == null) return [];
  return ref.watch(investorServiceProvider).listPerformance(record.id);
});

/// Analytics window in months (`null` = all history).
final investorAnalyticsMonthsProvider = StateProvider<int?>((ref) => 12);

final investorAnalyticsSnapshotProvider =
    FutureProvider<InvestorAnalyticsSnapshot>((ref) async {
  final record = await ref.watch(investorRecordProvider.future);
  if (record == null) {
    return const InvestorAnalyticsSnapshot(investorId: '');
  }
  final months = ref.watch(investorAnalyticsMonthsProvider);
  return ref.watch(investorServiceProvider).loadAnalyticsSnapshot(
        record.id,
        months: months,
      );
});

final investorConstructionProvider =
    FutureProvider<InvestorConstructionBundle>((ref) async {
  final record = await ref.watch(investorRecordProvider.future);
  if (record == null) return const InvestorConstructionBundle();
  return ref.watch(investorServiceProvider).loadConstruction(record.id);
});

final investorConversationsProvider =
    FutureProvider<List<InvestorConversation>>((ref) async {
  ref.watch(investorMessagesTickProvider);
  final record = await ref.watch(investorRecordProvider.future);
  if (record == null) return [];
  return ref.watch(investorServiceProvider).listConversations(record.id);
});

final investorConversationMessagesProvider =
    FutureProvider.family<List<InvestorMessage>, String>((
  ref,
  conversationId,
) async {
  ref.watch(investorMessagesTickProvider);
  final userId = ref.watch(identitySessionProvider).userId;
  if (userId == null) return [];
  return ref.watch(investorServiceProvider).listMessages(
        conversationId,
        userId: userId,
      );
});

final investorNotificationsProvider =
    FutureProvider<List<InvestorPortalNotification>>((ref) async {
  final record = await ref.watch(investorRecordProvider.future);
  if (record == null) return [];
  return ref.watch(investorServiceProvider).listNotifications(record.id);
});

final investorTicketsProvider =
    FutureProvider<List<InvestorSupportTicket>>((ref) async {
  ref.watch(investorTicketsTickProvider);
  final userId = ref.watch(identitySessionProvider).userId;
  if (userId == null) return [];
  return ref.watch(investorServiceProvider).listTickets();
});

final investorTicketMessagesProvider =
    FutureProvider.family<List<InvestorTicketMessage>, String>((
  ref,
  ticketId,
) async {
  ref.watch(investorTicketsTickProvider);
  final userId = ref.watch(identitySessionProvider).userId;
  if (userId == null) return [];
  return ref.watch(investorServiceProvider).listTicketMessages(ticketId);
});

final investorCommitmentsProvider =
    FutureProvider<List<InvestorCommitment>>((ref) async {
  final record = await ref.watch(investorRecordProvider.future);
  if (record == null) return const [];
  return ref.watch(investorServiceProvider).listCommitments();
});

final investorReferralsProvider =
    FutureProvider<InvestorReferralSummary>((ref) async {
  final record = await ref.watch(investorRecordProvider.future);
  if (record == null) return const InvestorReferralSummary();
  return ref.watch(investorServiceProvider).loadReferrals(record.id);
});

final investorKycBundleProvider =
    FutureProvider<InvestorKycBundle>((ref) async {
  final record = await ref.watch(investorRecordProvider.future);
  if (record == null) return const InvestorKycBundle();
  return ref.watch(investorServiceProvider).loadKycBundle(record.id);
});

/// Investor preference metadata (settings + realtime invalidation target).
final investorPreferencesProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final record = await ref.watch(investorRecordProvider.future);
  if (record == null) return const {};
  return ref.watch(investorServiceProvider).loadPreferences(record.id);
});
