import 'package:hdhomesproject/features/pms/domain/entities/pms_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads Property Command Center snapshot from Supabase (falls back to demo).
class PmsService {
  PmsService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<PmsCommandCenterSnapshot> loadCommandCenter() async {
    final demo = PmsDemo.snapshot();
    final client = _client;
    if (client == null) return demo;

    try {
      final propertyRows = await client.from('properties').select(
            'id, slug, title, property_code, city, '
            'inventory_status, development_status, marketing_status, '
            'publish_workflow_status, bedrooms, bathrooms, listing_price, '
            'promo_price, investor_price, rental_price, currency, '
            'performance_score, tags, ai_summary, is_featured, category_slug, '
            'property_types(name, slug), estates(name)',
          ).limit(100);

      final properties = <PmsProperty>[];
      for (final row in propertyRows) {
        final map = Map<String, dynamic>.from(row as Map);
        final typeRel = map['property_types'];
        if (typeRel is Map) {
          map['property_type'] =
              typeRel['name'] as String? ?? typeRel['slug'] as String?;
        }
        map['property_type'] ??= map['category_slug'];
        final estateRel = map['estates'];
        if (estateRel is Map) {
          map['estate_name'] = estateRel['name'];
        }
        properties.add(PmsProperty.fromJson(map));
      }

      if (properties.isEmpty) return demo;

      List<PmsInspection> inspections = demo.inspections;
      try {
        final inspRows = await client
            .from('property_inspections')
            .select()
            .order('scheduled_at', ascending: true)
            .limit(20);
        if (inspRows.isNotEmpty) {
          inspections = inspRows
              .map(
                (e) => PmsInspection.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<PmsLifecycleEvent> lifecycle = demo.lifecycle;
      try {
        final lifeRows = await client
            .from('property_lifecycle_events')
            .select()
            .order('occurred_at', ascending: false)
            .limit(30);
        if (lifeRows.isNotEmpty) {
          lifecycle = lifeRows
              .map(
                (e) => PmsLifecycleEvent.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<PmsApprovalStep> approvals = demo.approvalsPending;
      try {
        final approvalRows = await client
            .from('property_approvals')
            .select()
            .eq('status', 'pending')
            .order('step_order')
            .limit(30);
        if (approvalRows.isNotEmpty) {
          approvals = approvalRows
              .map(
                (e) => PmsApprovalStep.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      // Prefer computed scores when present.
      try {
        final scoreRows = await client
            .from('property_scores')
            .select('property_id, performance_score')
            .limit(100);
        if (scoreRows.isNotEmpty) {
          final byId = <String, double>{};
          for (final row in scoreRows) {
            final map = Map<String, dynamic>.from(row as Map);
            final id = map['property_id']?.toString();
            final score = (map['performance_score'] as num?)?.toDouble();
            if (id != null && score != null) byId[id] = score;
          }
          for (var i = 0; i < properties.length; i++) {
            final score = byId[properties[i].id];
            if (score != null) {
              final p = properties[i];
              properties[i] = PmsProperty(
                id: p.id,
                slug: p.slug,
                title: p.title,
                propertyCode: p.propertyCode,
                propertyType: p.propertyType,
                estateName: p.estateName,
                hierarchyPath: p.hierarchyPath,
                city: p.city,
                inventoryStatus: p.inventoryStatus,
                developmentStatus: p.developmentStatus,
                marketingStatus: p.marketingStatus,
                publishWorkflowStatus: p.publishWorkflowStatus,
                bedrooms: p.bedrooms,
                bathrooms: p.bathrooms,
                listingPrice: p.listingPrice,
                promoPrice: p.promoPrice,
                investorPrice: p.investorPrice,
                rentalPrice: p.rentalPrice,
                currency: p.currency,
                performanceScore: score,
                tags: p.tags,
                aiSummary: p.aiSummary,
                isFeatured: p.isFeatured,
              );
            }
          }
        }
      } catch (_) {}

      var estateTwin = demo.estateTwin;
      try {
        final estateRows = await client
            .from('estates')
            .select('id, name')
            .limit(5);
        if (estateRows.isNotEmpty) {
          final first = Map<String, dynamic>.from(estateRows.first as Map);
          final name = first['name'] as String? ?? demo.estateTwin.estateName;
          estateTwin = PmsEstateTwin(
            estateName: name,
            availableUnits: properties
                .where((p) => p.inventoryStatus == InventoryStatus.available)
                .length,
            reservedUnits: properties
                .where((p) => p.inventoryStatus == InventoryStatus.reserved)
                .length,
            soldUnits: properties
                .where((p) => p.inventoryStatus == InventoryStatus.sold)
                .length,
            constructionLabel: demo.estateTwin.constructionLabel,
            hierarchySample: demo.estateTwin.hierarchySample,
          );
        }
      } catch (_) {}

      return PmsCommandCenterSnapshot(
        kpis: PmsDemo.aggregateKpis(properties),
        properties: properties,
        inspections: inspections,
        lifecycle: lifecycle,
        approvalsPending: approvals,
        aiInsights: demo.aiInsights,
        estateTwin: estateTwin,
        inventoryIntelligence: demo.inventoryIntelligence,
        fromRemote: true,
        loadedAt: DateTime.now(),
      );
    } catch (_) {
      return demo;
    }
  }

  String generateAiSummary(PmsProperty property) {
    final status = property.inventoryStatus.label.toLowerCase();
    final type = property.propertyType;
    final city = property.city ?? 'Nigeria';
    final beds = property.bedrooms?.toStringAsFixed(
          property.bedrooms == property.bedrooms!.roundToDouble() ? 0 : 1,
        ) ??
        '—';
    final price = property.formatPrice(property.listingPrice);
    final score = property.performanceScore.toStringAsFixed(0);

    return 'AI summary: $beds-bed $type in $city currently $status '
        'at $price. Performance score $score/100. '
        '${property.estateName != null ? 'Estate: ${property.estateName}. ' : ''}'
        'Recommend reviewing marketing status (${property.marketingStatus.label}) '
        'and publish workflow (${property.publishWorkflowStatus.label}).';
  }

  /// Weighted performance helpers used by stubs / future score sync.
  static double computePerformanceScore({
    double demand = 0,
    double conversion = 0,
    double mediaQuality = 0,
    double investorInterest = 0,
  }) {
    final score = (demand * 0.3) +
        (conversion * 0.3) +
        (mediaQuality * 0.2) +
        (investorInterest * 0.2);
    return score.clamp(0, 100);
  }

  static double normalizeEngagement(int views, int favorites, int bookings) {
    final raw = (views * 0.4) + (favorites * 2.0) + (bookings * 5.0);
    return (raw / 10).clamp(0, 100);
  }
}
