import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/home/domain/roi_calculator_math.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final Provider<void> roiCalculatorRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = Supabase.instance.client;
  final channel = client.channel('public:roi-calculator')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'roi_calculator_settings',
      callback: (_) {
        ref.invalidate(cmsRoiCalculatorSettingsProvider);
        ref.invalidate(publishedRoiCalculatorSettingsProvider);
      },
    )
    ..subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

final cmsRoiCalculatorSettingsProvider =
    FutureProvider<CmsRoiCalculatorSettings?>((ref) async {
  if (!ref.watch(supabaseConfiguredProvider)) return null;
  return ref.watch(cmsServiceProvider).getRoiCalculatorSettings();
});

final publishedRoiCalculatorSettingsProvider =
    FutureProvider<CmsRoiCalculatorSettings>((ref) async {
  if (!ref.watch(supabaseConfiguredProvider)) {
    return const CmsRoiCalculatorSettings(id: 'local-fallback');
  }
  return ref.watch(cmsServiceProvider).getRoiCalculatorSettings();
});

class RoiCalculatorState {
  const RoiCalculatorState({
    required this.amount,
    required this.growth,
    required this.years,
  });

  final double amount;
  final double growth;
  final double years;

  RoiCalculatorState copyWith({
    double? amount,
    double? growth,
    double? years,
  }) {
    return RoiCalculatorState(
      amount: amount ?? this.amount,
      growth: growth ?? this.growth,
      years: years ?? this.years,
    );
  }
}

class RoiCalculatorController extends Notifier<RoiCalculatorState?> {
  String? _settingsId;
  String _method = 'compound';
  RoiCalculatorState? _draft;

  @override
  RoiCalculatorState? build() {
    final settingsAsync = ref.watch(publishedRoiCalculatorSettingsProvider);
    return settingsAsync.when(
      data: (settings) {
        if (!settings.isEnabled) {
          _draft = null;
          return null;
        }
        _method = settings.compoundingMethod;
        if (_settingsId == settings.id && _draft != null) {
          return RoiCalculatorState(
            amount: _draft!.amount
                .clamp(settings.amountMin, settings.amountMax)
                .toDouble(),
            growth: _draft!.growth
                .clamp(settings.growthMin, settings.growthMax)
                .toDouble(),
            years: _draft!.years
                .clamp(settings.yearsMin, settings.yearsMax)
                .toDouble(),
          );
        }
        _settingsId = settings.id;
        _draft = RoiCalculatorState(
          amount: settings.amountDefault
              .clamp(settings.amountMin, settings.amountMax)
              .toDouble(),
          growth: settings.growthDefault
              .clamp(settings.growthMin, settings.growthMax)
              .toDouble(),
          years: settings.yearsDefault
              .clamp(settings.yearsMin, settings.yearsMax)
              .toDouble(),
        );
        return _draft;
      },
      loading: () => _draft,
      error: (_, __) => _draft,
    );
  }

  RoiEstimate? get estimate {
    final s = state;
    if (s == null) return null;
    return RoiCalculatorMath.estimate(
      amount: s.amount,
      annualGrowthPercent: s.growth,
      years: s.years,
      method: _method,
    );
  }

  void setAmount(double value) {
    final s = state;
    if (s == null) return;
    _draft = s.copyWith(amount: value);
    state = _draft;
  }

  void setGrowth(double value) {
    final s = state;
    if (s == null) return;
    _draft = s.copyWith(growth: value);
    state = _draft;
  }

  void setYears(double value) {
    final s = state;
    if (s == null) return;
    _draft = s.copyWith(years: value);
    state = _draft;
  }

  void reset(CmsRoiCalculatorSettings settings) {
    _settingsId = settings.id;
    _method = settings.compoundingMethod;
    _draft = RoiCalculatorState(
      amount: settings.amountDefault
          .clamp(settings.amountMin, settings.amountMax)
          .toDouble(),
      growth: settings.growthDefault
          .clamp(settings.growthMin, settings.growthMax)
          .toDouble(),
      years: settings.yearsDefault
          .clamp(settings.yearsMin, settings.yearsMax)
          .toDouble(),
    );
    state = _draft;
  }
}

final roiCalculatorControllerProvider =
    NotifierProvider<RoiCalculatorController, RoiCalculatorState?>(
  RoiCalculatorController.new,
);
