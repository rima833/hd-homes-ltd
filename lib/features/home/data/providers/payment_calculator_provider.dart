import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/home/domain/payment_plan_math.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final calculatorRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = Supabase.instance.client;
  final channel = client.channel('public:payment-calculator')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'calculator_settings',
      callback: (_) => _invalidateCalculator(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'calculator_payment_plans',
      callback: (_) => _invalidateCalculator(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'calculator_plan_properties',
      callback: (_) => _invalidateCalculator(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'calculator_applications',
      callback: (_) {
        ref.invalidate(cmsCalculatorApplicationsProvider);
        ref.invalidate(myCalculatorApplicationsProvider);
      },
    )
    ..subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

void _invalidateCalculator(Ref ref) {
  ref.invalidate(cmsCalculatorSettingsProvider);
  ref.invalidate(cmsCalculatorPaymentPlansProvider);
  ref.invalidate(publishedCalculatorSettingsProvider);
  ref.invalidate(publishedCalculatorPaymentPlansProvider);
  ref.invalidate(publishedCalculatorPropertiesProvider);
}

final cmsCalculatorSettingsProvider = FutureProvider<CmsCalculatorSettings?>((
  ref,
) async {
  if (!ref.watch(supabaseConfiguredProvider)) return null;
  return ref.watch(cmsServiceProvider).getCalculatorSettings();
});

final cmsCalculatorPaymentPlansProvider =
    FutureProvider<List<CmsCalculatorPaymentPlan>>((ref) async {
      if (!ref.watch(supabaseConfiguredProvider)) return [];
      return ref.watch(cmsServiceProvider).listCalculatorPaymentPlans();
    });

final cmsCalculatorApplicationsProvider =
    FutureProvider<List<CmsCalculatorApplication>>((ref) async {
      if (!ref.watch(supabaseConfiguredProvider)) return [];
      return ref.watch(cmsServiceProvider).listCalculatorApplications();
    });

final myCalculatorApplicationsProvider =
    FutureProvider<List<CmsCalculatorApplication>>((ref) async {
      if (!ref.watch(supabaseConfiguredProvider)) return [];
      return ref.watch(cmsServiceProvider).listMyCalculatorApplications();
    });

final publishedCalculatorSettingsProvider =
    FutureProvider<CmsCalculatorSettings>((ref) async {
      ref.watch(calculatorRealtimeProvider);
      if (!ref.watch(supabaseConfiguredProvider)) {
        return const CmsCalculatorSettings(id: 'local-fallback');
      }
      return ref.watch(cmsServiceProvider).getCalculatorSettings();
    });

final publishedCalculatorPaymentPlansProvider =
    FutureProvider<List<CmsCalculatorPaymentPlan>>((ref) async {
      ref.watch(calculatorRealtimeProvider);
      if (!ref.watch(supabaseConfiguredProvider)) {
        return const [
          CmsCalculatorPaymentPlan(
            id: 'local-plan',
            name: 'Flexible Home Plan',
          ),
        ];
      }
      return ref
          .watch(cmsServiceProvider)
          .listPublishedCalculatorPaymentPlans();
    });

final publishedCalculatorPropertiesProvider =
    FutureProvider<List<CmsPropertyFeatured>>((ref) async {
      ref.watch(calculatorRealtimeProvider);
      if (!ref.watch(supabaseConfiguredProvider)) return [];
      return ref.watch(cmsServiceProvider).listPublishedProperties(limit: 80);
    });

/// Controllable calculator state for the public homepage section.
class PaymentCalculatorState {
  const PaymentCalculatorState({
    required this.planId,
    this.propertyId,
    required this.propertyPrice,
    required this.deposit,
    required this.months,
    required this.interestRate,
  });

  final String planId;
  final String? propertyId;
  final double propertyPrice;
  final double deposit;
  final double months;
  final double interestRate;

  PaymentCalculatorState copyWith({
    String? planId,
    String? propertyId,
    bool clearProperty = false,
    double? propertyPrice,
    double? deposit,
    double? months,
    double? interestRate,
  }) {
    return PaymentCalculatorState(
      planId: planId ?? this.planId,
      propertyId: clearProperty ? null : (propertyId ?? this.propertyId),
      propertyPrice: propertyPrice ?? this.propertyPrice,
      deposit: deposit ?? this.deposit,
      months: months ?? this.months,
      interestRate: interestRate ?? this.interestRate,
    );
  }
}

class PaymentCalculatorController extends Notifier<PaymentCalculatorState?> {
  PaymentCalculatorState? _draft;

  @override
  PaymentCalculatorState? build() {
    ref.watch(calculatorRealtimeProvider);
    final settings = ref.watch(publishedCalculatorSettingsProvider).valueOrNull;
    final plans = ref
        .watch(publishedCalculatorPaymentPlansProvider)
        .valueOrNull;
    if (settings == null || plans == null || plans.isEmpty) return _draft;

    final existing = _draft;
    if (existing != null && plans.any((p) => p.id == existing.planId)) {
      return existing;
    }

    final plan = plans.first;
    final price = settings.priceDefault.clamp(
      settings.priceMin,
      settings.priceMax,
    );
    final deposit = mathMax(
      plan.minDepositAmount,
      price * (plan.depositPercentDefault / 100),
    ).clamp(0, price);

    _draft = PaymentCalculatorState(
      planId: plan.id,
      propertyPrice: price.toDouble(),
      deposit: deposit.toDouble(),
      months: plan.durationMonthsDefault.toDouble(),
      interestRate: plan.interestRateDefault,
    );
    return _draft;
  }

  CmsCalculatorPaymentPlan? get selectedPlan {
    final plans =
        ref.read(publishedCalculatorPaymentPlansProvider).valueOrNull ??
        const [];
    final id = state?.planId;
    if (id == null) return plans.isEmpty ? null : plans.first;
    return plans.where((p) => p.id == id).firstOrNull ??
        (plans.isEmpty ? null : plans.first);
  }

  PaymentPlanEstimate? get estimate {
    final s = state;
    final plan = selectedPlan;
    if (s == null || plan == null) return null;
    return PaymentPlanMath.estimate(
      propertyPrice: s.propertyPrice,
      depositAmount: s.deposit,
      durationMonths: s.months.round(),
      annualInterestPercent: s.interestRate,
      method: plan.calculationMethod,
    );
  }

  String? validateForApply() {
    final s = state;
    final plan = selectedPlan;
    if (s == null || plan == null) return 'Payment plan is unavailable.';
    if (s.months.round() > plan.durationMonthsMax) {
      return 'Maximum duration is ${plan.durationMonthsMax} months.';
    }
    if (s.months.round() < plan.durationMonthsMin) {
      return 'Minimum duration is ${plan.durationMonthsMin} months.';
    }
    final minDeposit = mathMax(
      plan.minDepositAmount,
      s.propertyPrice * (plan.depositPercentMin / 100),
    );
    if (s.deposit + 0.01 < minDeposit) {
      return 'Minimum deposit for this plan is ₦${(minDeposit / 1e6).toStringAsFixed(1)}M.';
    }
    if (plan.maxDepositAmount != null && s.deposit > plan.maxDepositAmount!) {
      return 'Deposit exceeds the maximum allowed for this plan.';
    }
    if (!plan.isGlobal &&
        (s.propertyId == null || !plan.propertyIds.contains(s.propertyId))) {
      return 'Select an eligible property for this payment plan.';
    }
    return null;
  }

  void selectPlan(CmsCalculatorPaymentPlan plan) {
    final current = state;
    if (current == null) return;
    final price = current.propertyPrice;
    final deposit = mathMax(
      plan.minDepositAmount,
      price * (plan.depositPercentDefault / 100),
    ).clamp(0, price);
    _draft = current.copyWith(
      planId: plan.id,
      clearProperty: plan.isGlobal,
      deposit: deposit.toDouble(),
      months: plan.durationMonthsDefault.toDouble(),
      interestRate: plan.interestRateDefault,
    );
    state = _draft;
  }

  void selectProperty(CmsPropertyFeatured? property) {
    final current = state;
    if (current == null) return;
    if (property == null) {
      _draft = current.copyWith(clearProperty: true);
      state = _draft;
      return;
    }
    final price =
        (property.listingPrice ?? property.promoPrice ?? current.propertyPrice)
            .toDouble();
    final plan = selectedPlan;
    final deposit = plan == null
        ? current.deposit
        : mathMax(
            plan.minDepositAmount,
            price * (plan.depositPercentDefault / 100),
          ).clamp(0, price);
    _draft = current.copyWith(
      propertyId: property.id,
      propertyPrice: price,
      deposit: deposit.toDouble(),
    );
    state = _draft;
  }

  void setPrice(double value) {
    final current = state;
    final plan = selectedPlan;
    if (current == null) return;
    final price = value;
    var deposit = current.deposit.clamp(0, price);
    if (plan != null) {
      final minDeposit = mathMax(
        plan.minDepositAmount,
        price * (plan.depositPercentMin / 100),
      );
      if (deposit < minDeposit) deposit = minDeposit.clamp(0, price);
    }
    _draft = current.copyWith(
      propertyPrice: price,
      deposit: deposit.toDouble(),
      clearProperty: true,
    );
    state = _draft;
  }

  void setDeposit(double value) {
    final current = state;
    if (current == null) return;
    _draft = current.copyWith(deposit: value.clamp(0, current.propertyPrice));
    state = _draft;
  }

  void setMonths(double value) {
    final current = state;
    if (current == null) return;
    _draft = current.copyWith(months: value);
    state = _draft;
  }

  void setInterest(double value) {
    final current = state;
    if (current == null) return;
    _draft = current.copyWith(interestRate: value);
    state = _draft;
  }
}

double mathMax(double a, double b) => a > b ? a : b;

final paymentCalculatorControllerProvider =
    NotifierProvider<PaymentCalculatorController, PaymentCalculatorState?>(
      PaymentCalculatorController.new,
    );
