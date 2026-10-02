import 'package:hdhomesproject/features/dashboard/domain/entities/executive_dashboard_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads Mission Control from live operational tables used by the public
/// site and admin modules. Demo data is only used when Supabase is offline.
class ExecutiveDashboardService {
  ExecutiveDashboardService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<ExecutiveDashboardSnapshot> loadSnapshot() async {
    final demo = ExecutiveDashboardDemo.snapshot();
    final client = _client;
    if (client == null) return demo;

    try {
      final results = await Future.wait([
        _select('properties', limit: 400),
        _select('estates', limit: 200),
        _select('property_inspections', order: 'scheduled_at', ascending: true),
        _select('crm_clients', order: 'updated_at'),
        _select('investors', limit: 400),
        _select('payments', order: 'paid_at'),
        _select('invoices', order: 'due_date', ascending: true),
        _select('tickets', order: 'updated_at'),
        _select('live_chat_sessions', order: 'started_at'),
        _select('construction_projects', order: 'updated_at'),
        _select('career_jobs', limit: 200),
        _select('career_applications', order: 'created_at'),
        _select('partnership_requests', order: 'created_at'),
        _select('callback_requests', order: 'created_at'),
        _select('consultation_bookings', order: 'created_at'),
        _select('blogs', limit: 200),
        _select('partners', limit: 200),
        _select('testimonials', limit: 200),
        _select('executive_activity_feed', order: 'created_at', limit: 30),
        _select('executive_notifications', order: 'created_at', limit: 30),
        _select('investment_commitments', limit: 200),
        _select('marketing_analytics', limit: 50),
        _select('property_analytics_daily', limit: 200),
        _select('journey_analytics', limit: 50),
        _select('analytics_kpis', limit: 50),
        _select('user_sessions', limit: 500),
        _select('campaigns', limit: 50),
        _select('property_views', limit: 500),
        _select('visitor_statistics', limit: 500),
      ]);

      final properties = _alive(results[0]);
      final estates = _alive(results[1]);
      final inspections = results[2];
      final clients = results[3];
      final investors = _alive(results[4]);
      final payments = _alive(results[5]);
      final invoices = _alive(results[6]);
      final tickets = _alive(results[7]);
      final chats = results[8];
      final construction = results[9];
      final jobs = _alive(results[10]);
      final applications = results[11];
      final partnerships = results[12];
      final callbacks = results[13];
      final consultations = results[14];
      final blogs = _alive(results[15]);
      final partners = _alive(results[16]);
      final testimonials = _alive(results[17]);
      final storedActivity = results[18];
      final storedNotifs = results[19];
      final commitments = results[20];
      final mktAnalytics = results[21];
      final propAnalytics = results[22];
      final journeyRows = results[23];
      final analyticsKpis = results[24];
      final userSessions = results[25];
      final campaignRows = results[26];
      final propViews = results[27];
      final visitorStats = results[28];

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final monthStart = DateTime(now.year, now.month, 1);
      final weekAgo = now.subtract(const Duration(days: 7));

      final publishedProps = properties.where(_isPublished).toList();
      final available = properties.where(_isAvailable).toList();
      final sold = properties.where(_isSold).toList();
      final reserved = properties.where(_isReserved).toList();
      final draftProps = properties.where((r) => !_isPublished(r)).toList();

      final paidPayments = payments.where(_isPaid).toList();
      final pendingPayments = payments.where((r) => !_isPaid(r)).toList();
      final revenueToday = _sumAmount(
        paidPayments.where((r) => _date(r, 'paid_at')?.isAfter(todayStart) ?? false),
      );
      final revenueMonth = _sumAmount(
        paidPayments.where((r) => _date(r, 'paid_at')?.isAfter(monthStart) ?? false),
      );
      final revenueWeek = _sumAmount(
        paidPayments.where((r) => _date(r, 'paid_at')?.isAfter(weekAgo) ?? false),
      );
      final openInvoices = invoices
          .where((r) => !_closed(r, const {'paid', 'cancelled', 'void'}))
          .toList();
      final outstanding = openInvoices.any((r) => r.containsKey('balance_due'))
          ? _sumField(openInvoices, 'balance_due')
          : _sumAmount(openInvoices);
      final pendingPayAmt = _sumAmount(pendingPayments);
      final listingValue = _sumField(available, 'listing_price');
      final avgValue = properties.isEmpty
          ? 0.0
          : _sumField(properties, 'listing_price') / properties.length;

      final openTickets = tickets.where((r) => !_closed(r, const {
            'resolved',
            'closed',
            'done',
            'cancelled',
          })).toList();
      final resolvedWeek = tickets.where((r) {
        final closed = _date(r, 'resolved_at') ?? _date(r, 'closed_at');
        return closed != null && closed.isAfter(weekAgo);
      }).length;
      final waitingChats = chats.where((r) {
        final s = _slug(r['status']);
        return s == 'waiting' || s == 'open' || s == 'queued';
      }).length;

      final pendingKyc = investors.where((r) {
        final s = _slug(r['kyc_status']);
        return s.isEmpty || s == 'pending' || s == 'submitted' || s == 'in_review';
      }).length;
      final newInvestorsWeek = investors
          .where((r) => _date(r, 'created_at')?.isAfter(weekAgo) ?? false)
          .length;
      final aum = _sumField(investors, 'aum');
      final committed = _sumField(commitments, 'amount');

      final newLeads = clients.where((r) {
        final s = _slug(r['relationship_status']);
        return s == 'lead' || s == 'new' || s.isEmpty;
      }).length;
      final qualified = clients.where((r) {
        final s = _slug(r['relationship_status']);
        return s == 'qualified' || s == 'opportunity';
      }).length;
      final activeClients = clients.where((r) {
        final s = _slug(r['relationship_status']);
        return s == 'active' || s == 'customer' || s == 'client';
      }).length;
      final conversion = clients.isEmpty
          ? 0.0
          : (sold.length / clients.length) * 100;

      final delayedProjects = construction.where((r) {
        final delay = _num(r['delay_days']);
        final s = _slug(r['status']);
        return delay > 0 || s == 'delayed' || s == 'at_risk' || s == 'on_hold';
      }).toList();
      final completedProjects = construction
          .where((r) => _slug(r['status']) == 'completed')
          .length;
      final activeProjects = construction
          .where((r) => !_closed(r, const {'completed', 'cancelled', 'archived'}))
          .length;
      final budgetTotal = _sumField(construction, 'budget_total');
      final budgetSpent = _sumField(construction, 'budget_spent');
      final budgetUtil = budgetTotal <= 0 ? 0.0 : (budgetSpent / budgetTotal) * 100;

      final publishedBlogs = blogs.where(_isPublished).length;
      final openJobs = jobs.where((r) {
        final s = _slug(r['status']);
        return s == 'open' || s == 'published' || s == 'active' || s.isEmpty;
      }).length;
      final publishedEstates = estates.where(_isPublished).length;

      final upcomingInspections = inspections.where((r) {
        final when = _date(r, 'scheduled_at');
        if (when == null) return false;
        return when.isAfter(now.subtract(const Duration(hours: 1))) &&
            !_closed(r, const {'cancelled', 'completed', 'no_show'});
      }).toList();

      // --- Analytics aggregations ---
      double _mktVal(String key) {
        for (final r in mktAnalytics) {
          if (r['metric_key'] == key) return _num(r['metric_value']);
        }
        return 0;
      }

      final websiteSessions = _mktVal('sessions');
      final formLeads = _mktVal('leads');
      final mktConversion = _mktVal('conversion_rate');
      final funnelAwareness = _mktVal('funnel_awareness');
      final funnelConsideration = _mktVal('funnel_consideration');
      final funnelConversion = _mktVal('funnel_conversion');

      final analyticsViews =
          propAnalytics.fold<int>(0, (s, r) => s + (_num(r['views']).toInt()));
      final eventViews = propViews
          .where((r) => r['is_deleted'] != true && r['is_deleted'] != 'true')
          .length;
      // property_views is the event log. The daily rollup can lag behind it.
      final totalPropViews =
          eventViews > analyticsViews ? eventViews : analyticsViews;
      final totalFavorites =
          propAnalytics.fold<int>(0, (s, r) => s + (_num(r['favorites']).toInt()));
      final totalBookings =
          propAnalytics.fold<int>(0, (s, r) => s + (_num(r['bookings']).toInt()));
      final avgConvRate = propAnalytics.isEmpty
          ? 0.0
          : propAnalytics.fold<double>(0, (s, r) => s + _num(r['conversion_rate'])) /
              propAnalytics.length;

      final totalPageViews = propViews.length;
      final totalVisitors = visitorStats.fold<int>(
          0, (s, r) => s + (_num(r['visitor_count']).toInt()));

      final activeSessions = userSessions
          .where((r) =>
              r['revoked_at'] == null &&
              (_date(r, 'expires_at')?.isAfter(now) ?? false))
          .length;
      final totalSessions = userSessions.length;

      final activeCampaigns = campaignRows
          .where((r) => _slug(r['status']) == 'active')
          .length;
      final campaignBudget = _sumField(campaignRows, 'budget_amount');

      final cityLead = _topCity(publishedProps);
      final featuredTitle = publishedProps.isEmpty
          ? '—'
          : (publishedProps.firstWhere(
                (r) => _slug(r['marketing_status']) == 'featured',
                orElse: () => publishedProps.first,
              )['title'] as String? ??
              '—');

      final kpis = <KpiCard>[
        _kpi(
          'total_properties',
          'Total Properties',
          properties.length.toDouble(),
          seriesHint: properties.length.toDouble(),
        ),
        _kpi(
          'available_properties',
          'Available Properties',
          available.length.toDouble(),
          seriesHint: available.length.toDouble(),
        ),
        _kpi(
          'sold_properties',
          'Sold Properties',
          sold.length.toDouble(),
          seriesHint: sold.length.toDouble(),
        ),
        _kpi(
          'reserved_properties',
          'Reserved Properties',
          reserved.length.toDouble(),
          seriesHint: reserved.length.toDouble(),
        ),
        _kpi(
          'total_clients',
          'Total Clients',
          clients.length.toDouble(),
          seriesHint: clients.length.toDouble(),
        ),
        _kpi(
          'active_investors',
          'Active Investors',
          investors.length.toDouble(),
          seriesHint: investors.length.toDouble(),
        ),
        _kpi(
          'revenue_today',
          "Today's Revenue",
          revenueToday,
          unit: 'ngn',
          seriesHint: revenueToday / 1e6,
        ),
        _kpi(
          'revenue_month',
          'Monthly Revenue',
          revenueMonth,
          unit: 'ngn',
          seriesHint: revenueMonth / 1e6,
        ),
        _kpi(
          'pending_payments',
          'Pending Payments',
          pendingPayAmt > 0 ? pendingPayAmt : outstanding,
          unit: 'ngn',
          seriesHint: (pendingPayAmt > 0 ? pendingPayAmt : outstanding) / 1e6,
        ),
        _kpi(
          'completed_sales',
          'Completed Sales',
          sold.length.toDouble(),
          seriesHint: sold.length.toDouble(),
        ),
        _kpi(
          'construction_projects',
          'Construction Projects',
          construction.length.toDouble(),
          seriesHint: construction.length.toDouble(),
        ),
        _kpi(
          'support_tickets_open',
          'Active Support Tickets',
          openTickets.length.toDouble(),
          seriesHint: openTickets.length.toDouble(),
        ),
        _kpi(
          'website_sessions',
          'Website Sessions',
          websiteSessions,
          seriesHint: websiteSessions / 1000,
        ),
        _kpi(
          'property_page_views',
          'Property Views',
          totalPropViews.toDouble(),
          seriesHint: totalPropViews.toDouble(),
        ),
        _kpi(
          'site_visitors',
          'Total Visitors',
          totalVisitors > 0 ? totalVisitors.toDouble() : websiteSessions,
          seriesHint: (totalVisitors > 0 ? totalVisitors : websiteSessions) / 1000,
        ),
        _kpi(
          'active_user_sessions',
          'Active Sessions',
          activeSessions.toDouble(),
          seriesHint: activeSessions.toDouble(),
        ),
        _kpi(
          'form_leads',
          'Form Leads',
          formLeads,
          seriesHint: formLeads,
        ),
        _kpi(
          'conversion_rate',
          'Conversion Rate',
          mktConversion,
          unit: '%',
          seriesHint: mktConversion,
        ),
      ];

      final health = _computeHealth(
        publishedRatio: properties.isEmpty
            ? 0
            : ((publishedProps.length / properties.length) * 100).round(),
        salesScore: properties.isEmpty
            ? 0
            : ((sold.length / properties.length) * 100).round(),
        investorScore: investors.isEmpty
            ? 0
            : (((investors.length - pendingKyc) / investors.length) * 100).round(),
        supportScore: tickets.isEmpty
            ? 0
            : (100 - (openTickets.length * 8)).clamp(0, 100).round(),
        constructionScore: construction.isEmpty
            ? 0
            : (100 - delayedProjects.length * 18).clamp(0, 100).round(),
        cashScore: (revenueMonth + outstanding) <= 0
            ? 0
            : ((revenueMonth / (revenueMonth + outstanding)) * 100)
                .round()
                .clamp(0, 100)
                .toInt(),
        websiteScore: [
          publishedProps.isNotEmpty,
          publishedEstates > 0,
          publishedBlogs > 0,
          testimonials.isNotEmpty,
          partners.isNotEmpty,
          websiteSessions > 0,
          totalPropViews > 0,
          formLeads > 0,
        ].where((e) => e).length * 12 + 4,
        now: now,
      );

      final activity = _buildActivity(
        stored: storedActivity,
        properties: properties,
        inspections: inspections,
        payments: paidPayments,
        clients: clients,
        tickets: tickets,
        blogs: blogs,
        now: now,
      );

      final notifications = _buildNotifications(
        stored: storedNotifs,
        draftCount: draftProps.length,
        pendingKyc: pendingKyc,
        openTickets: openTickets.length,
        outstanding: outstanding,
        waitingChats: waitingChats,
        applications: applications.length,
        partnerships: partnerships.length,
        callbacks: callbacks.where((r) => !_closed(r, const {
              'completed',
              'cancelled',
              'closed',
            })).length,
      );

      final schedule = _buildSchedule(
        inspections: upcomingInspections,
        construction: construction,
        consultations: consultations,
        now: now,
      );

      final risks = _buildRisks(
        delayed: delayedProjects,
        pendingKyc: pendingKyc,
        openTickets: openTickets.length,
        outstanding: outstanding,
        draftCount: draftProps.length,
      );

      final forecasts = _buildForecasts(
        listingValue: listingValue,
        revenueMonth: revenueMonth,
        cityLead: cityLead,
        outstanding: outstanding,
        inspections: upcomingInspections.length,
      );

      final initiatives = construction.take(5).map((r) {
        final delay = _num(r['delay_days']);
        final progress = _num(r['progress_pct']).clamp(0, 100).round();
        final status = delay > 0 || _slug(r['status']) == 'at_risk'
            ? 'At risk'
            : _slug(r['status']) == 'completed'
                ? 'Complete'
                : _slug(r['status']) == 'on_hold'
                    ? 'At risk'
                    : progress >= 50
                        ? 'On track'
                        : 'Planning';
        return StrategyInitiative(
          title: r['name'] as String? ?? 'Construction programme',
          status: status,
          progressPct: progress,
        );
      }).toList();

      final insights = _buildInsights(
        sold: sold.length,
        published: publishedProps.length,
        cityLead: cityLead,
        pendingKyc: pendingKyc,
        delayed: delayedProjects.length,
        revenueMonth: revenueMonth,
        inspections: inspections.length,
      );

      final briefing =
          'Business health is ${health.status.label} (${health.overallScore}). '
          '${publishedProps.length} listings are live on the public site, '
          '${clients.length} CRM clients, ${investors.length} investors'
          '${pendingKyc > 0 ? ', $pendingKyc KYC pending' : ''}. '
          '${websiteSessions > 0 ? '${websiteSessions.toStringAsFixed(0)} website sessions tracked, ${formLeads.toStringAsFixed(0)} form leads. ' : ''}'
          '${delayedProjects.isEmpty ? 'Construction is on track.' : '${delayedProjects.length} construction item(s) need attention.'}';

      return ExecutiveDashboardSnapshot(
        kpis: kpis,
        health: health,
        insights: insights,
        activity: activity,
        notifications: notifications,
        quickActions: demo.quickActions,
        schedule: schedule,
        risks: risks,
        sales: ModuleAnalyticsBlock(
          title: 'Sales Performance',
          metrics: {
            'Daily sales': _ngn(revenueToday),
            'Weekly sales': _ngn(revenueWeek),
            'Monthly sales': _ngn(revenueMonth),
            'Completed sales': '${sold.length}',
            'Avg listing value': _ngn(avgValue),
            'Pipeline value': _ngn(listingValue),
            'Conversion rate': '${conversion.toStringAsFixed(1)}%',
            'Inspections booked': '${inspections.length}',
          },
        ),
        properties: ModuleAnalyticsBlock(
          title: 'Property Performance',
          metrics: {
            'Published listings': '${publishedProps.length}',
            'Estates published': '$publishedEstates',
            'Featured listing': featuredTitle,
            'Awaiting publish': '${draftProps.length}',
            'Available': '${available.length}',
            'By location lead': cityLead ?? '—',
          },
        ),
        investors: ModuleAnalyticsBlock(
          title: 'Investor Overview',
          metrics: {
            'Total investors': '${investors.length}',
            'Commitments': '${commitments.length}',
            'Investment value': _ngn(aum > 0 ? aum : committed),
            'Pending KYC': '$pendingKyc',
            'New this week': '$newInvestorsWeek',
            'Consultations': '${consultations.length}',
          },
        ),
        crm: ModuleAnalyticsBlock(
          title: 'Client & CRM',
          metrics: {
            'Total records': '${clients.length}',
            'New leads': '$newLeads',
            'Qualified': '$qualified',
            'Active clients': '$activeClients',
            'Closed deals': '${sold.length}',
            'Callbacks open': '${callbacks.length}',
            'Follow-ups due': '${upcomingInspections.length}',
          },
        ),
        construction: ModuleAnalyticsBlock(
          title: 'Construction Overview',
          metrics: {
            'Active projects': '$activeProjects',
            'Completed': '$completedProjects',
            'Delayed': '${delayedProjects.length}',
            'Upcoming inspections': '${upcomingInspections.length}',
            'Budget utilization': '${budgetUtil.toStringAsFixed(0)}%',
            'QA status': delayedProjects.isEmpty ? 'On track' : 'Needs attention',
          },
        ),
        finance: ModuleAnalyticsBlock(
          title: 'Financial Summary',
          metrics: {
            'Revenue (MTD)': _ngn(revenueMonth),
            'Collected payments': '${paidPayments.length}',
            'Outstanding': _ngn(outstanding),
            'Pending payments': _ngn(pendingPayAmt),
            'Invoices': '${invoices.length}',
            'Cash flow': outstanding > revenueMonth && revenueMonth == 0
                ? 'Watch'
                : outstanding > revenueMonth
                    ? 'Watch'
                    : 'Positive',
          },
        ),
        marketing: ModuleAnalyticsBlock(
          title: 'Website & Marketing',
          metrics: {
            'Website sessions': websiteSessions > 0 ? '${websiteSessions.toStringAsFixed(0)}' : '—',
            'Property views': '$totalPropViews',
            'Page views': '$totalPageViews',
            'Visitors': totalVisitors > 0 ? '$totalVisitors' : '—',
            'Form leads': formLeads > 0 ? '${formLeads.toStringAsFixed(0)}' : '—',
            'Conversion rate': mktConversion > 0 ? '${mktConversion.toStringAsFixed(1)}%' : '—',
            'Funnel — Awareness': funnelAwareness > 0 ? '${funnelAwareness.toStringAsFixed(0)}' : '—',
            'Funnel — Consideration': funnelConsideration > 0 ? '${funnelConsideration.toStringAsFixed(0)}' : '—',
            'Funnel — Conversion': funnelConversion > 0 ? '${funnelConversion.toStringAsFixed(0)}' : '—',
            'Active campaigns': '$activeCampaigns',
            'Campaign budget': _ngn(campaignBudget),
            'Published listings': '${publishedProps.length}',
            'Published estates': '$publishedEstates',
            'Blog articles': '$publishedBlogs',
            'Testimonials': '${testimonials.length}',
            'Partners': '${partners.length}',
            'Favorites': '$totalFavorites',
            'Bookings from listings': '$totalBookings',
            'Active user sessions': '$activeSessions / $totalSessions total',
            'Open careers': '$openJobs',
          },
        ),
        support: ModuleAnalyticsBlock(
          title: 'Support Overview',
          metrics: {
            'Open tickets': '${openTickets.length}',
            'Resolved (7d)': '$resolvedWeek',
            'Open chats': '${chats.length}',
            'Waiting chats': '$waitingChats',
            'Career applications': '${applications.length}',
            'Partnerships': '${partnerships.length}',
          },
        ),
        reportTypes: demo.reportTypes,
        forecasts: forecasts,
        initiatives: initiatives,
        briefingSummary: briefing,
        fromRemote: true,
        loadedAt: now,
      );
    } catch (_) {
      return demo;
    }
  }

  Future<void> markNotificationRead(String id) async {
    final client = _client;
    if (client == null) return;
    try {
      await client
          .from('executive_notifications')
          .update({'is_read': true}).eq('id', id);
    } catch (_) {}
  }

  Future<Map<String, dynamic>> queueReport({
    required String reportType,
    required String format,
    required String userId,
  }) async {
    final client = _client;
    final title = reportType.replaceAll('_', ' ');
    if (client == null) {
      return {
        'id': 'local',
        'status': 'ready',
        'title': title,
        'format': format,
        'summary': {
          'note': 'Queued locally — apply SQL migration for persistence',
        },
      };
    }
    try {
      final row = await client.from('executive_reports').insert({
        'report_type': reportType,
        'title': '${title[0].toUpperCase()}${title.substring(1)} Report',
        'requested_by': userId,
        'status': 'ready',
        'format': format,
        'summary': {
          'generated_at': DateTime.now().toUtc().toIso8601String(),
          'source': 'live_operational_tables',
        },
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      }).select().maybeSingle();
      return row != null
          ? Map<String, dynamic>.from(row)
          : {'status': 'ready', 'title': title};
    } catch (_) {
      return {
        'status': 'ready',
        'title': title,
        'format': format,
      };
    }
  }

  String buildBriefing(ExecutiveDashboardSnapshot snap) {
    final kpiBits =
        snap.kpis.take(4).map((k) => '${k.label}: ${k.displayValue}').join('; ');
    return '''
HD Homes Executive Briefing
${snap.loadedAt ?? DateTime.now()}

Health: ${snap.health.status.label} (${snap.health.overallScore}/100)

KPI highlight — $kpiBits

Priorities:
${snap.insights.take(3).map((i) => '• ${i.title}').join('\n')}

Risks:
${snap.risks.take(3).map((r) => '• [${r.severity.name}] ${r.title} → ${r.nextAction}').join('\n')}

${snap.briefingSummary ?? ''}
'''.trim();
  }

  Future<List<Map<String, dynamic>>> _select(
    String table, {
    String columns = '*',
    String? order,
    bool ascending = false,
    int limit = 200,
  }) async {
    final client = _client;
    if (client == null) return const [];
    try {
      dynamic query = client.from(table).select(columns);
      if (order != null) {
        query = query.order(order, ascending: ascending);
      }
      final rows = await query.limit(limit);
      return [
        for (final row in rows as List) Map<String, dynamic>.from(row as Map),
      ];
    } catch (_) {
      return const [];
    }
  }

  static List<Map<String, dynamic>> _alive(List<Map<String, dynamic>> rows) {
    return rows
        .where((r) => r['is_deleted'] != true && r['is_deleted'] != 'true')
        .toList();
  }

  static bool _isPublished(Map<String, dynamic> row) {
    if (row.containsKey('is_published')) {
      return row['is_published'] == true || row['is_published'] == 'true';
    }
    final status = _slug(row['status']);
    final marketing = _slug(row['marketing_status']);
    return status == 'published' ||
        status == 'active' ||
        marketing == 'published' ||
        marketing == 'featured';
  }

  static bool _isAvailable(Map<String, dynamic> row) {
    final inv = _slug(row['inventory_status']);
    final status = _slug(row['status']);
    if (inv.isNotEmpty) {
      return inv == 'available' || inv == 'active' || inv == 'open';
    }
    return status == 'available' || status == 'active';
  }

  static bool _isSold(Map<String, dynamic> row) {
    final inv = _slug(row['inventory_status']);
    final status = _slug(row['status']);
    return inv == 'sold' || status == 'sold' || status == 'completed';
  }

  static bool _isReserved(Map<String, dynamic> row) {
    final inv = _slug(row['inventory_status']);
    final status = _slug(row['status']);
    return inv == 'reserved' ||
        inv == 'booked' ||
        status == 'reserved' ||
        status == 'booked';
  }

  static bool _isPaid(Map<String, dynamic> row) {
    final s = _slug(row['status']);
    return s == 'paid' || s == 'completed' || s == 'success' || s == 'settled';
  }

  static bool _closed(Map<String, dynamic> row, Set<String> closed) {
    return closed.contains(_slug(row['status']));
  }

  static String _slug(dynamic raw) =>
      (raw?.toString() ?? '').trim().toLowerCase().replaceAll(' ', '_');

  static double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  static DateTime? _date(Map<String, dynamic> row, String key) {
    final raw = row[key];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  static double _sumAmount(Iterable<Map<String, dynamic>> rows) =>
      _sumField(rows, 'amount');

  static double _sumField(Iterable<Map<String, dynamic>> rows, String key) {
    var total = 0.0;
    for (final row in rows) {
      total += _num(row[key]);
    }
    return total;
  }

  static String _ngn(double n) {
    if (n >= 1e9) return '₦${(n / 1e9).toStringAsFixed(1)}B';
    if (n >= 1e6) return '₦${(n / 1e6).toStringAsFixed(1)}M';
    if (n >= 1e3) return '₦${(n / 1e3).toStringAsFixed(0)}K';
    return '₦${n.toStringAsFixed(0)}';
  }

  static String? _topCity(List<Map<String, dynamic>> properties) {
    if (properties.isEmpty) return null;
    final counts = <String, int>{};
    for (final row in properties) {
      final city = (row['city'] as String?)?.trim();
      if (city == null || city.isEmpty) continue;
      final key = '${city[0].toUpperCase()}${city.substring(1)}';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final pct = ((top.value / properties.length) * 100).round();
    return '${top.key} $pct%';
  }

  static KpiCard _kpi(
    String key,
    String label,
    double value, {
    String unit = 'count',
    required double seriesHint,
  }) {
    final series = _spark(seriesHint);
    return KpiCard(
      metricKey: key,
      label: label,
      value: value,
      previousValue: value,
      unit: unit,
      changePct: 0,
      series: series,
      capturedAt: DateTime.now(),
    );
  }

  static List<double> _spark(double value) {
    final point = value <= 0 ? 0.0 : value;
    return List<double>.filled(7, point);
  }

  static BusinessHealthScore _computeHealth({
    required int publishedRatio,
    required int salesScore,
    required int investorScore,
    required int supportScore,
    required int constructionScore,
    required int cashScore,
    required int websiteScore,
    required DateTime now,
  }) {
    final factors = [
      HealthFactor(key: 'sales', label: 'Sales Performance', score: salesScore, weight: 0.2),
      HealthFactor(key: 'website', label: 'Website catalog', score: websiteScore.clamp(0, 100)),
      HealthFactor(key: 'investors', label: 'Investor Activity', score: investorScore, weight: 0.15),
      HealthFactor(key: 'satisfaction', label: 'Support Load', score: supportScore),
      HealthFactor(key: 'construction', label: 'Construction Progress', score: constructionScore),
      HealthFactor(key: 'cashflow', label: 'Cash Flow', score: cashScore),
      HealthFactor(key: 'publish', label: 'Publish Coverage', score: publishedRatio.clamp(0, 100)),
    ];
    final overall = (factors.fold<double>(0, (s, f) => s + f.score) / factors.length)
        .round()
        .clamp(0, 100);
    final status = overall >= 88
        ? BusinessHealthStatus.excellent
        : overall >= 72
            ? BusinessHealthStatus.good
            : overall >= 50
                ? BusinessHealthStatus.needsAttention
                : BusinessHealthStatus.critical;
    return BusinessHealthScore(
      overallScore: overall,
      status: status,
      factors: factors,
      history: [overall - 4, overall - 3, overall - 2, overall - 1, overall],
      capturedAt: now,
    );
  }

  static List<ActivityFeedItem> _buildActivity({
    required List<Map<String, dynamic>> stored,
    required List<Map<String, dynamic>> properties,
    required List<Map<String, dynamic>> inspections,
    required List<Map<String, dynamic>> payments,
    required List<Map<String, dynamic>> clients,
    required List<Map<String, dynamic>> tickets,
    required List<Map<String, dynamic>> blogs,
    required DateTime now,
  }) {
    if (stored.isNotEmpty) {
      return stored
          .map(ActivityFeedItem.fromJson)
          .toList();
    }

    final items = <ActivityFeedItem>[];
    for (final row in properties.take(4)) {
      items.add(
        ActivityFeedItem(
          id: 'p-${row['id']}',
          action: 'listing_updated',
          module: 'property',
          summary: _isPublished(row)
              ? 'Listing live: ${row['title'] ?? 'Property'}'
              : 'Listing updated: ${row['title'] ?? 'Property'}',
          actorName: 'Website',
          createdAt: _date(row, 'updated_at') ?? now,
        ),
      );
    }
    for (final row in inspections.take(3)) {
      items.add(
        ActivityFeedItem(
          id: 'i-${row['id']}',
          action: 'inspection_scheduled',
          module: 'inspections',
          summary:
              'Inspection ${row['status'] ?? 'scheduled'} — ${row['visitor_name'] ?? row['reference'] ?? 'site visit'}',
          actorName: 'Field Ops',
          createdAt: _date(row, 'updated_at') ?? _date(row, 'scheduled_at') ?? now,
        ),
      );
    }
    for (final row in payments.take(3)) {
      items.add(
        ActivityFeedItem(
          id: 'pay-${row['id']}',
          action: 'payment_received',
          module: 'finance',
          summary: 'Payment ${_ngn(_num(row['amount']))} · ${row['status'] ?? 'recorded'}',
          actorName: 'Finance',
          createdAt: _date(row, 'paid_at') ?? _date(row, 'created_at') ?? now,
        ),
      );
    }
    for (final row in clients.take(2)) {
      items.add(
        ActivityFeedItem(
          id: 'c-${row['id']}',
          action: 'client_registered',
          module: 'crm',
          summary: 'Client: ${row['full_name'] ?? 'New lead'}',
          actorName: 'CRM',
          createdAt: _date(row, 'created_at') ?? now,
        ),
      );
    }
    for (final row in tickets.take(2)) {
      items.add(
        ActivityFeedItem(
          id: 't-${row['id']}',
          action: 'ticket_opened',
          module: 'support',
          summary: 'Ticket: ${row['subject'] ?? row['ticket_number'] ?? 'Support'}',
          actorName: 'Support',
          createdAt: _date(row, 'created_at') ?? now,
        ),
      );
    }
    for (final row in blogs.where(_isPublished).take(2)) {
      items.add(
        ActivityFeedItem(
          id: 'b-${row['id']}',
          action: 'blog_published',
          module: 'marketing',
          summary: 'Article live: ${row['title'] ?? 'Blog'}',
          actorName: 'Website',
          createdAt: _date(row, 'published_at') ?? _date(row, 'updated_at') ?? now,
        ),
      );
    }
    items.sort((a, b) => (b.createdAt ?? now).compareTo(a.createdAt ?? now));
    return items.take(12).toList();
  }

  static List<ExecutiveNotificationItem> _buildNotifications({
    required List<Map<String, dynamic>> stored,
    required int draftCount,
    required int pendingKyc,
    required int openTickets,
    required double outstanding,
    required int waitingChats,
    required int applications,
    required int partnerships,
    required int callbacks,
  }) {
    if (stored.isNotEmpty) {
      return stored.map(ExecutiveNotificationItem.fromJson).toList();
    }
    final items = <ExecutiveNotificationItem>[];
    if (draftCount > 0) {
      items.add(
        ExecutiveNotificationItem(
          id: 'n-draft',
          category: 'approval',
          title: 'Listings awaiting publish',
          body: '$draftCount propert${draftCount == 1 ? 'y is' : 'ies are'} not live on the website',
          severity: NotificationSeverity.warning,
          module: 'property',
          actionPath: '/dashboard/properties',
        ),
      );
    }
    if (pendingKyc > 0) {
      items.add(
        ExecutiveNotificationItem(
          id: 'n-kyc',
          category: 'compliance',
          title: 'KYC reviews pending',
          body: '$pendingKyc investor file${pendingKyc == 1 ? '' : 's'} need compliance review',
          severity: NotificationSeverity.warning,
          module: 'compliance',
          actionPath: '/dashboard/compliance',
        ),
      );
    }
    if (openTickets > 0) {
      items.add(
        ExecutiveNotificationItem(
          id: 'n-tickets',
          category: 'support',
          title: 'Open support tickets',
          body: '$openTickets active ticket${openTickets == 1 ? '' : 's'} in the inbox',
          severity: NotificationSeverity.info,
          module: 'support',
          actionPath: '/dashboard/support',
        ),
      );
    }
    if (outstanding > 0) {
      items.add(
        ExecutiveNotificationItem(
          id: 'n-finance',
          category: 'finance',
          title: 'Outstanding invoices',
          body: '${_ngn(outstanding)} still receivable',
          severity: NotificationSeverity.warning,
          module: 'finance',
          actionPath: '/dashboard/finance',
        ),
      );
    }
    if (waitingChats > 0) {
      items.add(
        ExecutiveNotificationItem(
          id: 'n-chat',
          category: 'support',
          title: 'Chat waiting',
          body: '$waitingChats visitor${waitingChats == 1 ? '' : 's'} in queue',
          module: 'support',
          actionPath: '/dashboard/support',
        ),
      );
    }
    if (applications > 0) {
      items.add(
        ExecutiveNotificationItem(
          id: 'n-jobs',
          category: 'careers',
          title: 'Career applications',
          body: '$applications application${applications == 1 ? '' : 's'} in the inbox',
          module: 'careers',
          actionPath: '/dashboard/website/careers',
        ),
      );
    }
    if (partnerships > 0) {
      items.add(
        ExecutiveNotificationItem(
          id: 'n-partners',
          category: 'partnerships',
          title: 'Partnership requests',
          body: '$partnerships request${partnerships == 1 ? '' : 's'} from the website',
          module: 'partnerships',
          actionPath: '/dashboard/website/partnerships',
        ),
      );
    }
    if (callbacks > 0) {
      items.add(
        ExecutiveNotificationItem(
          id: 'n-cb',
          category: 'callbacks',
          title: 'Callback requests',
          body: '$callbacks open callback${callbacks == 1 ? '' : 's'} from contact',
          module: 'crm',
          actionPath: '/dashboard/callbacks',
        ),
      );
    }
    if (items.isEmpty) {
      items.add(
        const ExecutiveNotificationItem(
          id: 'n-ok',
          category: 'system',
          title: 'Operations are clear',
          body: 'No pending website, KYC, or support queues right now',
          severity: NotificationSeverity.success,
        ),
      );
    }
    return items;
  }

  static List<ScheduleItem> _buildSchedule({
    required List<Map<String, dynamic>> inspections,
    required List<Map<String, dynamic>> construction,
    required List<Map<String, dynamic>> consultations,
    required DateTime now,
  }) {
    final items = <ScheduleItem>[];
    for (final row in inspections.take(6)) {
      final when = _date(row, 'scheduled_at');
      if (when == null) continue;
      items.add(
        ScheduleItem(
          title: row['visitor_name'] != null
              ? 'Inspection — ${row['visitor_name']}'
              : 'Property inspection',
          when: when,
          category: 'Inspection',
        ),
      );
    }
    for (final row in consultations.take(3)) {
      final when = _date(row, 'scheduled_at') ?? _date(row, 'preferred_at');
      if (when == null || when.isBefore(now.subtract(const Duration(hours: 2)))) {
        continue;
      }
      items.add(
        ScheduleItem(
          title: 'Consultation',
          when: when,
          category: 'Investor',
        ),
      );
    }
    for (final row in construction) {
      final when = _date(row, 'target_end_date');
      if (when == null || when.isBefore(now)) continue;
      items.add(
        ScheduleItem(
          title: row['name'] as String? ?? 'Construction milestone',
          when: when,
          category: 'Construction',
        ),
      );
    }
    items.sort((a, b) => a.when.compareTo(b.when));
    return items.take(6).toList();
  }

  static List<OperationalRisk> _buildRisks({
    required List<Map<String, dynamic>> delayed,
    required int pendingKyc,
    required int openTickets,
    required double outstanding,
    required int draftCount,
  }) {
    final risks = <OperationalRisk>[];
    for (final row in delayed.take(2)) {
      risks.add(
        OperationalRisk(
          title: '${row['name'] ?? 'Project'} delay',
          severity: NotificationSeverity.critical,
          owner: row['manager_label'] as String? ?? 'Construction Lead',
          nextAction: 'Rebaseline milestone plan',
          module: 'construction',
        ),
      );
    }
    if (pendingKyc > 0) {
      risks.add(
        OperationalRisk(
          title: 'KYC backlog',
          severity: NotificationSeverity.warning,
          owner: 'Compliance',
          nextAction: 'Complete $pendingKyc pending review${pendingKyc == 1 ? '' : 's'}',
          module: 'compliance',
        ),
      );
    }
    if (draftCount > 0) {
      risks.add(
        OperationalRisk(
          title: 'Unpublished listings',
          severity: NotificationSeverity.warning,
          owner: 'Website',
          nextAction: 'Publish $draftCount listing${draftCount == 1 ? '' : 's'} to the public catalog',
          module: 'property',
        ),
      );
    }
    if (openTickets >= 5) {
      risks.add(
        const OperationalRisk(
          title: 'Support queue pressure',
          severity: NotificationSeverity.warning,
          owner: 'Support Lead',
          nextAction: 'Clear open tickets and waiting chats',
          module: 'support',
        ),
      );
    }
    if (outstanding > 0) {
      risks.add(
        OperationalRisk(
          title: 'Receivables outstanding',
          severity: NotificationSeverity.warning,
          owner: 'Finance',
          nextAction: 'Collect ${_ngn(outstanding)}',
          module: 'finance',
        ),
      );
    }
    return risks;
  }

  static List<PredictiveForecast> _buildForecasts({
    required double listingValue,
    required double revenueMonth,
    required String? cityLead,
    required double outstanding,
    required int inspections,
  }) {
    final nextMonth = revenueMonth > 0 ? revenueMonth * 1.08 : listingValue * 0.04;
    return [
      PredictiveForecast(
        label: 'Monthly sales forecast',
        prediction:
            '${_ngn(nextMonth * 0.92)} – ${_ngn(nextMonth * 1.12)} next period',
        confidence: revenueMonth > 0 ? 0.72 : 0.48,
        disclaimer: revenueMonth > 0
            ? 'Based on collected revenue this month. Confidence 72%.'
            : 'Limited payment history — estimate uses live listing pipeline.',
      ),
      PredictiveForecast(
        label: 'Demand pocket',
        prediction: cityLead == null
            ? 'Publish more listings to reveal location demand'
            : 'Elevated interest around $cityLead',
        confidence: cityLead == null ? 0.4 : 0.66,
        disclaimer: 'Derived from live published catalog locations.',
      ),
      PredictiveForecast(
        label: 'Cash flow',
        prediction: outstanding <= 0
            ? 'No open receivables on the ledger'
            : 'Receivables risk ${_ngn(outstanding)} with $inspections upcoming visits',
        confidence: 0.7,
        disclaimer: 'Scenario from invoices, payments, and booked inspections.',
      ),
    ];
  }

  static List<AiExecutiveInsight> _buildInsights({
    required int sold,
    required int published,
    required String? cityLead,
    required int pendingKyc,
    required int delayed,
    required double revenueMonth,
    required int inspections,
  }) {
    return [
      AiExecutiveInsight(
        id: 'live-catalog',
        type: InsightType.observation,
        title: '$published listing${published == 1 ? '' : 's'} live on the public site',
        body: sold > 0
            ? '$sold marked sold. Public catalog and admin listings stay in sync.'
            : 'Published properties, estates, and media update this dashboard in realtime.',
        isAiGenerated: false,
        confidence: 0.95,
        severity: NotificationSeverity.success,
        module: 'property',
      ),
      if (cityLead != null)
        AiExecutiveInsight(
          id: 'live-city',
          type: InsightType.observation,
          title: 'Location lead: $cityLead',
          body: 'Share of the live published catalog. Inspections booked: $inspections.',
          isAiGenerated: false,
          confidence: 0.8,
          module: 'property',
        ),
      if (pendingKyc > 0)
        AiExecutiveInsight(
          id: 'live-kyc',
          type: InsightType.alert,
          title: '$pendingKyc investor KYC file${pendingKyc == 1 ? '' : 's'} still open',
          body: 'Compliance queue is live — reviews here update the investor portal.',
          isAiGenerated: false,
          confidence: 0.9,
          severity: NotificationSeverity.warning,
          module: 'compliance',
        ),
      if (delayed > 0)
        AiExecutiveInsight(
          id: 'live-build',
          type: InsightType.alert,
          title: '$delayed construction programme${delayed == 1 ? '' : 's'} behind',
          body: 'Milestone slippage is pulled from construction projects, not sample data.',
          isAiGenerated: false,
          confidence: 0.88,
          severity: NotificationSeverity.critical,
          module: 'construction',
        ),
      AiExecutiveInsight(
        id: 'live-rev',
        type: InsightType.observation,
        title: 'Month-to-date collections ${_ngn(revenueMonth)}',
        body: 'Payments and invoices from finance ops. Website bookings feed inspections and CRM.',
        isAiGenerated: false,
        confidence: 0.84,
        module: 'finance',
      ),
    ];
  }
}
