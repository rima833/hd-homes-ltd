import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/navigation/app_sidebar.dart';
import 'package:hdhomesproject/core/navigation/navigation_config.dart';
import 'package:hdhomesproject/features/investor/domain/entities/investor_models.dart';
import 'package:hdhomesproject/features/investor/presentation/providers/investor_portal_realtime_provider.dart';
import 'package:hdhomesproject/features/imp/domain/entities/imp_models.dart';
import 'package:hdhomesproject/features/imp/presentation/providers/imp_controller.dart';

/// Phase 15 — admin → investor end-to-end scenario contracts.
///
/// These tests encode the production flow without requiring a live auth session:
/// IMP / Finance / CPMS write paths → investor portal routes, deep links, and models.
void main() {
  group('Mobile bottom nav (Phase 14)', () {
    test('destinations are Dashboard · Portfolio · Payments · More', () {
      final paths = NavigationConfig.investorBottomNav.map((e) => e.path);
      expect(
        paths,
        [
          RoutePaths.investor,
          RoutePaths.investorPortfolio,
          RoutePaths.investorPayments,
          RoutePaths.investorMore,
        ],
      );
    });

    test('longest-prefix selection highlights nested portfolio routes', () {
      final items = NavigationConfig.investorBottomNav;
      expect(
        AppBottomNav.indexForLocation(items, '/investor'),
        0,
      );
      expect(
        AppBottomNav.indexForLocation(items, '/investor/portfolio'),
        1,
      );
      expect(
        AppBottomNav.indexForLocation(
          items,
          '/investor/portfolio/hold-123',
        ),
        1,
      );
      expect(
        AppBottomNav.indexForLocation(items, '/investor/payments'),
        2,
      );
      expect(
        AppBottomNav.indexForLocation(items, '/investor/more'),
        3,
      );
      // Secondary modules are not bottom-nav selected (More is exact only).
      expect(
        AppBottomNav.indexForLocation(items, '/investor/documents'),
        0, // falls back to dashboard prefix only if nothing longer matches
      );
    });
  });

  group('Scenario A — Assign investment (Phase 13)', () {
    test('holding deep link targets portfolio detail', () {
      const holdingId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
      expect(
        RoutePaths.investorHoldingDetail(holdingId),
        '/investor/portfolio/$holdingId',
      );

      final notification = InvestorPortalNotification.fromJson({
        'id': 'n1',
        'title': 'New investment assigned',
        'body': 'Holding added',
        'is_read': false,
        'metadata': {
          'category': 'portfolio',
          'route': RoutePaths.investorHoldingDetail(holdingId),
          'holding_id': holdingId,
        },
      });
      expect(notification.portalRoute, startsWith('/investor/portfolio/'));
      expect(notification.categoryLabel, 'Portfolio');
    });

    test('IMP KYC statuses cover portal verification states', () {
      expect(KycStatus.approved.slug, 'approved');
      expect(KycStatus.underReview.slug, 'under_review');
      expect(KycStatus.needsResubmission.slug, 'needs_resubmission');
      expect(KycStatus.fromSlug('partially_approved'), KycStatus.partiallyApproved);
    });
  });

  group('Scenario B — Publish document (Phase 8/13)', () {
    test('document notification deep-links to vault', () {
      final n = InvestorPortalNotification.fromJson({
        'id': 'n-doc',
        'title': 'New document available',
        'is_read': false,
        'metadata': {
          'category': 'documents',
          'route': RoutePaths.investorDocuments,
        },
      });
      expect(n.portalRoute, RoutePaths.investorDocuments);
      expect(n.categoryLabel, 'Documents');
    });
  });

  group('Scenario C — Message investor (Phase 9/13)', () {
    test('message notification deep-links to messages', () {
      final n = InvestorPortalNotification.fromJson({
        'id': 'n-msg',
        'title': 'New message from HD Homes',
        'is_read': false,
        'metadata': {
          'category': 'messages',
          'route': RoutePaths.investorMessages,
          'conversation_id': 'conv-1',
        },
      });
      expect(n.portalRoute, RoutePaths.investorMessages);
      expect(n.categoryLabel, 'Messages');
    });
  });

  group('Scenario D — KYC verification (Phase 11)', () {
    test('needsAction flags pending and rejected statuses', () {
      expect(
        const InvestorKycBundle(kycStatus: 'pending').needsAction,
        isTrue,
      );
      expect(
        const InvestorKycBundle(kycStatus: 'needs_resubmission').needsAction,
        isTrue,
      );
      expect(
        const InvestorKycBundle(kycStatus: 'approved').needsAction,
        isFalse,
      );
    });

    test('parses review history rows', () {
      final review = InvestorKycReview.fromJson({
        'id': 'r1',
        'status': 'under_review',
        'notes': 'Awaiting ID',
        'created_at': '2026-09-04T10:00:00Z',
      });
      expect(review.statusLabel, 'under review');
      expect(review.notes, 'Awaiting ID');
    });
  });

  group('Scenario E — Notifications center (Phase 12)', () {
    test('rejects unsafe external routes for in-app navigation', () {
      final unsafe = InvestorPortalNotification.fromJson({
        'id': 'n-bad',
        'title': 'Phish',
        'metadata': {'route': 'https://evil.example'},
      });
      expect(unsafe.portalRoute, isNull);

      final safeHttps = InvestorPortalNotification.fromJson({
        'id': 'n-https',
        'title': 'Ext',
        'metadata': {'route': 'https://hdhomes.ng/investment'},
      });
      // Only /investor* portal routes are navigable in-app.
      expect(safeHttps.portalRoute, isNull);
    });

    test('mark-read contract uses unread count on list', () {
      final items = [
        InvestorPortalNotification.fromJson({
          'id': '1',
          'title': 'A',
          'is_read': false,
          'metadata': {},
        }),
        InvestorPortalNotification.fromJson({
          'id': '2',
          'title': 'B',
          'is_read': true,
          'metadata': {},
        }),
      ];
      expect(items.where((n) => !n.isRead).length, 1);
    });
  });

  group('Scenario F — Payments (Phase 6)', () {
    test('payments route is a primary bottom-nav destination', () {
      expect(
        NavigationConfig.investorBottomNav.any(
          (i) => i.path == RoutePaths.investorPayments,
        ),
        isTrue,
      );
    });
  });

  group('Scenario G — Referrals (Phase 11)', () {
    test('successful referrals count paid commissions only', () {
      final summary = InvestorReferralSummary(
        referralCode: 'HDH-INV-TEST',
        pendingEarnings: 250000,
        paidEarnings: 100000,
        commissions: [
          const InvestorReferralCommission(
            id: 'c1',
            amount: 250000,
            status: 'pending',
          ),
          const InvestorReferralCommission(
            id: 'c2',
            amount: 100000,
            status: 'paid',
          ),
        ],
      );
      expect(summary.successfulReferrals, 1);
      expect(summary.totalEarnings, 350000);
      expect(summary.programRules.steps, isNotEmpty);
    });
  });

  group('Scenario H — Realtime hub coverage', () {
    test('hub listens to admin write-path tables', () {
      const required = [
        'portfolio_holdings',
        'investor_documents',
        'investor_notifications',
        'investor_conversations',
        'investor_conversation_messages',
        'investor_kyc_reviews',
        'investor_payment_intents',
        'investment_distributions',
        'construction_progress_updates',
      ];
      for (final table in required) {
        expect(
          investorPortalRealtimeTables,
          contains(table),
          reason: 'Realtime hub must include $table',
        );
      }
    });
  });

  group('Scenario I — Module route map completeness', () {
    test('sidebar modules all have RoutePaths', () {
      final sidebarPaths = NavigationConfig.investorNav
          .where((n) => !n.isSectionHeader && !n.isAction && n.path.isNotEmpty)
          .map((n) => n.path)
          .toSet();

      // Core modules from Part 26.
      for (final path in [
        RoutePaths.investor,
        RoutePaths.investorPortfolio,
        RoutePaths.investorAnalytics,
        RoutePaths.investorTools,
        RoutePaths.investorConstruction,
        RoutePaths.investorReports,
        RoutePaths.investorPayments,
        RoutePaths.investorDocuments,
        RoutePaths.investorReferrals,
        RoutePaths.investorMessages,
        RoutePaths.investorSupport,
        RoutePaths.investorSettings,
        RoutePaths.investorNotifications,
      ]) {
        expect(sidebarPaths, contains(path));
      }
    });

    test('More hub path is distinct from Settings', () {
      expect(RoutePaths.investorMore, isNot(RoutePaths.investorSettings));
      expect(RoutePaths.investorMore, '/investor/more');
    });
  });

  group('Admin → investor action matrix (Phase 13 contracts)', () {
    test('each IMP write maps to an investor surface', () {
      const matrix = <String, String>{
        'admin_assign_investor_holding': '/investor/portfolio',
        'admin_publish_document_to_investor': '/investor/documents',
        'admin_message_investor': '/investor/messages',
        'admin_verify_investor_kyc': '/investor/settings',
        'admin_publish_investor_notification': '/investor/notifications',
        'admin_confirm_investor_intent': '/investor/payments',
        'admin_publish_investor_report': '/investor/reports',
        'admin_award_investor_referral': '/investor/referrals',
        'admin_get_investor_construction': '/investor/construction',
        'support_ticket_send_message': '/investor/support',
        'admin_fund_investment_commitment': '/investor/portfolio',
        'admin_set_website_investment_opportunity_status': '/investment',
      };
      for (final entry in matrix.entries) {
        expect(
          entry.value.startsWith('/investor') || entry.value == '/investment',
          isTrue,
          reason: '${entry.key} must map to a public or portal surface',
        );
        expect(
          entry.key.startsWith('admin_') || entry.key.startsWith('support_'),
          isTrue,
        );
      }
    });
  });

  group('Scenario J — IMP command center → portal sync (ops desk)', () {
    test('desk KPI cards stay honest and labeled for ops', () {
      final kpis = ImpDeskKpis.fromJson({
        'total_investors': 1,
        'active_investors': 1,
        'total_aum': 0,
        'capital_raised': 0,
        'upcoming_distributions': 0,
        'pending_payments': 2,
        'kyc_pending': 1,
        'overdue_actions': 0,
        'open_opportunities': 3,
        'generated_at': '2026-09-15T09:00:00Z',
      }).toKpiCards();

      expect(
        kpis.map((k) => k.label),
        containsAll([
          'Total Investors',
          'Active Investors',
          'Total AUM',
          'Capital Raised',
          'Upcoming Distributions',
          'Pending Payments',
          'KYC Pending',
          'Overdue Actions',
        ]),
      );
      // Zeros must remain zeros — no fabricated AUM.
      final aum = kpis.firstWhere((k) => k.label == 'Total AUM');
      expect(aum.value, 0);
    });

    test('consolidated IMP tabs cover ops → portal surfaces', () {
      expect(
        ImpCommandTab.values.map((t) => t.label).toList(),
        [
          'Overview',
          'Investors',
          'Capital',
          'Payments',
          'Compliance',
          'Support',
          'Insights',
          '360° Investor',
        ],
      );
      expect(
        ImpCapitalSegment.values.map((s) => s.label),
        containsAll([
          'Investments',
          'Capital Raise',
          'Portfolio',
          'Distributions',
        ]),
      );
      expect(
        ImpComplianceSegment.values.map((s) => s.label),
        containsAll(['KYC', 'Documents']),
      );
      expect(
        ImpInsightsSegment.values.map((s) => s.label),
        containsAll(['Reports', 'Activity', 'Alerts']),
      );
    });

    test('notification deep links used by IMP desk are portal-safe', () {
      const routes = <String>[
        '/investor',
        '/investor/portfolio',
        '/investor/payments',
        '/investor/documents',
        '/investor/construction',
        '/investor/messages',
        '/investor/notifications',
        '/investor/support',
        '/investor/reports',
      ];
      for (final route in routes) {
        final n = InvestorPortalNotification.fromJson({
          'id': 'n-$route',
          'title': 'Ops ping',
          'is_read': false,
          'metadata': {'route': route, 'category': 'general'},
        });
        expect(n.portalRoute, route);
      }
    });

    test('construction snapshot carries cover + update media for portal parity', () {
      final snap = ImpConstructionSnapshot.fromJson({
        'overall_percent': 42,
        'projects': [
          {
            'id': 'p1',
            'name': 'Horizon Block A',
            'progress_pct': 42,
            'status': 'active',
            'schedule_status': 'on_track',
            'cover_image_url': 'https://res.cloudinary.com/demo/cover.jpg',
          },
        ],
        'updates': [
          {
            'id': 'u1',
            'title': 'Roofing complete',
            'project_name': 'Horizon Block A',
            'short_description': 'Deck poured',
            'published_at': '2026-09-10T12:00:00Z',
            'media': [
              {
                'id': 'm1',
                'media_type': 'image',
                'file_url': 'https://res.cloudinary.com/demo/site.jpg',
                'thumbnail_url': 'https://res.cloudinary.com/demo/site_t.jpg',
              },
              {
                'id': 'm2',
                'media_type': 'video',
                'file_url': 'https://res.cloudinary.com/demo/drone.mp4',
                'thumbnail_url': 'https://res.cloudinary.com/demo/drone_t.jpg',
              },
            ],
          },
        ],
      });
      expect(snap.overallPercent, 42);
      expect(snap.projects.first.coverImageUrl, contains('cloudinary'));
      expect(snap.updates.first.media, hasLength(2));
      expect(snap.updates.first.media.first.displayUrl, contains('site_t'));
      expect(snap.updates.first.media.last.isVideo, isTrue);
      expect(
        investorPortalRealtimeTables,
        containsAll([
          'construction_projects',
          'construction_progress_updates',
          'construction_update_media',
        ]),
      );
    });

    test('support thread models parse conversation + ticket replies', () {
      final convo = ImpSupportThreadMessage.fromConversationJson({
        'id': 'cm1',
        'body': 'Thanks for the update',
        'sender_id': 'staff-1',
        'created_at': '2026-09-15T08:00:00Z',
      }, currentUserId: 'staff-1');
      expect(convo.isStaff, isTrue);
      expect(convo.body, 'Thanks for the update');

      final ticket = ImpSupportThreadMessage.fromTicketJson({
        'id': 'tm1',
        'message': 'Internal follow-up',
        'sender_type': 'agent',
        'sender_name': 'Ada',
        'is_internal': true,
        'created_at': '2026-09-15T08:05:00Z',
      });
      expect(ticket.isInternal, isTrue);
      expect(ticket.isStaff, isTrue);
      expect(
        investorPortalRealtimeTables,
        containsAll(['tickets', 'ticket_messages']),
      );
    });

    test('website opportunity publish status gates public visibility', () {
      final published = ImpWebsiteOpportunity.fromJson({
        'id': 'w1',
        'project_name': 'Lekki Fund',
        'slug': 'lekki-fund',
        'status': 'active',
        'opportunity_status': 'open',
        'is_featured': true,
      });
      final draft = ImpWebsiteOpportunity.fromJson({
        'id': 'w2',
        'project_name': 'Draft Fund',
        'slug': 'draft-fund',
        'status': 'draft',
        'opportunity_status': 'coming_soon',
      });
      expect(published.isPublished, isTrue);
      expect(published.isFeatured, isTrue);
      expect(draft.isPublished, isFalse);
    });

    test('IMP notification row preserves portal deep link metadata', () {
      final row = ImpNotificationRow.fromJson({
        'id': 'nr1',
        'investor_id': 'inv-1',
        'title': 'Report ready',
        'body': 'Q3 pack',
        'channel': 'in_app',
        'is_read': false,
        'created_at': '2026-09-15T09:00:00Z',
        'metadata': {'route': RoutePaths.investorReports},
        'investors': {'full_name': 'Ada Investor'},
      });
      expect(row.route, RoutePaths.investorReports);
      expect(row.investorName, 'Ada Investor');
    });

    test('IMP command-center realtime covers ops write surfaces', () {
      expect(
        impCommandCenterRealtimeTables,
        containsAll([
          'investor_reports',
          'investor_statements',
          'investor_referral_commissions',
          'website_investment_opportunities',
          'ticket_messages',
          'investor_conversation_messages',
          'construction_projects',
          'investor_notifications',
        ]),
      );
    });
  });
}
