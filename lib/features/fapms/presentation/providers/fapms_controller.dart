import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/fapms/domain/entities/fapms_models.dart';
import 'package:hdhomesproject/features/fapms/domain/services/fapms_service.dart';
import 'package:hdhomesproject/features/fapms/presentation/providers/payment_verification_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final fapmsServiceProvider = Provider<FapmsService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return FapmsService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final fapmsSnapshotProvider =
    FutureProvider<FapmsCommandCenterSnapshot>((ref) async {
  return ref.watch(fapmsServiceProvider).loadCommandCenter();
});

final fapmsLiveTickProvider = StateProvider<int>((ref) => 0);

void _bumpLive(Ref ref) {
  ref.read(fapmsLiveTickProvider.notifier).state++;
  ref.invalidate(fapmsSnapshotProvider);
}

/// Invalidates snapshot when finance live tables change.
final fapmsRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('fapms-command-center')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'invoices',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'payments',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'payment_transactions',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'client_payment_intents',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'payment_verifications',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'investor_payment_intents',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'expenses',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'budgets',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'budget_lines',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'budget_variances',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'financial_statements',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'bank_accounts',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'bank_transactions',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'journal_entries',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'accounts_receivable',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'accounts_payable',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'installments',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'finance_receipts',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'company_receiving_accounts',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'finance_activity_logs',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'finance_notifications',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'payment_charges',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'investment_distributions',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'investment_receiving_accounts',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'payment_settings',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'client_property_applications',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'calculator_applications',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'client_referral_commissions',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'investor_referral_commissions',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'sales_commissions',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'payment_methods',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'late_fee_rules',
      callback: (_) => _bumpLive(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'investor_wallets',
      callback: (_) => _bumpLive(ref),
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

/// Focused ops tabs — daily HD Homes finance work across the live website.
enum FapmsCommandTab {
  overview,
  verification,
  payments,
  installments,
  invoices,
  expenses,
  banking,
  investor,
  leads,
  commissions,
  setup;

  String get label => switch (this) {
        FapmsCommandTab.overview => 'Overview',
        FapmsCommandTab.verification => 'Verification',
        FapmsCommandTab.payments => 'Payments',
        FapmsCommandTab.installments => 'Installments',
        FapmsCommandTab.invoices => 'Invoices',
        FapmsCommandTab.expenses => 'Expenses',
        FapmsCommandTab.banking => 'Banking',
        FapmsCommandTab.investor => 'Investor',
        FapmsCommandTab.leads => 'Leads',
        FapmsCommandTab.commissions => 'Commissions',
        FapmsCommandTab.setup => 'Setup',
      };
}

class FapmsUiState {
  const FapmsUiState({
    this.searchQuery = '',
    this.statusFilter,
    this.selectedTab = FapmsCommandTab.overview,
    this.lastMessage,
  });

  final String searchQuery;
  final String? statusFilter;
  final FapmsCommandTab selectedTab;
  final String? lastMessage;

  FapmsUiState copyWith({
    String? searchQuery,
    String? statusFilter,
    bool clearStatusFilter = false,
    FapmsCommandTab? selectedTab,
    String? lastMessage,
    bool clearMessage = false,
  }) {
    return FapmsUiState(
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      selectedTab: selectedTab ?? this.selectedTab,
      lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
    );
  }
}

class FapmsController extends Notifier<FapmsUiState> {
  @override
  FapmsUiState build() {
    ref.watch(fapmsRealtimeProvider);
    ref.watch(paymentVerificationRealtimeProvider);
    return const FapmsUiState();
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setStatusFilter(String? statusSlug) {
    if (statusSlug == null) {
      state = state.copyWith(clearStatusFilter: true);
    } else {
      state = state.copyWith(statusFilter: statusSlug);
    }
  }

  void setTab(FapmsCommandTab tab) {
    state = state.copyWith(selectedTab: tab);
  }

  void setMessage(String message) {
    state = state.copyWith(lastMessage: message);
  }

  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }

  Future<void> refresh() async {
    ref.invalidate(fapmsSnapshotProvider);
    ref.invalidate(paymentIntentsProvider);
    ref.invalidate(pendingPaymentIntentsProvider);
    ref.invalidate(pendingVerificationCountProvider);
  }

  List<FapmsInvoice> filteredInvoices(FapmsCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.invoices.where((inv) {
      if (state.statusFilter != null && inv.status.slug != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return inv.invoiceNumber.toLowerCase().contains(q) ||
          inv.partyName.toLowerCase().contains(q);
    }).toList();
  }

  List<FapmsExpense> filteredExpenses(FapmsCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.expenses.where((e) {
      if (state.statusFilter != null && e.status.slug != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return e.expenseCode.toLowerCase().contains(q) ||
          e.title.toLowerCase().contains(q) ||
          (e.vendorLabel?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<FapmsPaymentTx> filteredPayments(FapmsCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.paymentTxs.where((tx) {
      if (q.isEmpty) return true;
      return tx.provider.toLowerCase().contains(q) ||
          tx.sourceLabel.toLowerCase().contains(q) ||
          (tx.providerReference?.toLowerCase().contains(q) ?? false);
    }).toList();
  }
}

final fapmsControllerProvider =
    NotifierProvider<FapmsController, FapmsUiState>(FapmsController.new);
