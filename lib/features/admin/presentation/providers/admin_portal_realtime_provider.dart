import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/audit_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/ai_workspace_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/communication_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/enterprise_search_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/kyc_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/organization_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/people_rbac_realtime_provider.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/personalization_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/platform_users_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/profile_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/rbac_controller.dart';
import 'package:hdhomesproject/features/biadw/presentation/providers/biadw_controller.dart';
import 'package:hdhomesproject/features/callback/presentation/providers/callback_providers.dart';
import 'package:hdhomesproject/features/careers/data/providers/careers_cms_provider.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/consultation/presentation/providers/consultation_admin_providers.dart';
import 'package:hdhomesproject/features/contact/data/providers/office_directory_provider.dart';
import 'package:hdhomesproject/features/cpms/presentation/providers/cpms_controller.dart';
import 'package:hdhomesproject/features/crm/presentation/providers/crm_controller.dart';
import 'package:hdhomesproject/features/cshop/presentation/providers/cshop_controller.dart';
import 'package:hdhomesproject/features/dashboard/presentation/providers/executive_dashboard_controller.dart';
import 'package:hdhomesproject/features/ddcms/presentation/providers/ddcms_controller.dart';
import 'package:hdhomesproject/features/dxp/presentation/providers/dxp_controller.dart';
import 'package:hdhomesproject/features/eaih/presentation/providers/eaih_controller.dart';
import 'package:hdhomesproject/features/eip/presentation/providers/eip_controller.dart';
import 'package:hdhomesproject/features/esp/presentation/providers/esp_controller.dart';
import 'package:hdhomesproject/features/fapms/presentation/providers/fapms_controller.dart';
import 'package:hdhomesproject/features/home/data/providers/home_content_provider.dart';
import 'package:hdhomesproject/features/home/data/providers/payment_calculator_provider.dart';
import 'package:hdhomesproject/features/home/data/providers/roi_calculator_provider.dart';
import 'package:hdhomesproject/features/imp/presentation/providers/imp_controller.dart';
import 'package:hdhomesproject/features/inspection/presentation/providers/inspection_admin_providers.dart';
import 'package:hdhomesproject/features/pms/presentation/providers/pms_controller.dart';
import 'package:hdhomesproject/features/sbms/presentation/providers/sbms_controller.dart';
import 'package:hdhomesproject/features/services/data/providers/services_cms_admin_provider.dart';
import 'package:hdhomesproject/features/website_forms/presentation/providers/website_forms_providers.dart';

/// Keeps every admin Supabase Realtime subscription alive while the admin
/// [PortalShell] is mounted — lists and dashboards refresh without manual reload.
final adminPortalRealtimeHubProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) return;

  // Website CMS + published catalog mirrors
  ref.watch(blogCmsRealtimeProvider);
  ref.watch(homepageHeroRealtimeProvider);
  ref.watch(homepageFeaturedRealtimeProvider);
  ref.watch(homepageContentRealtimeProvider);
  ref.watch(publishedEstatesRealtimeProvider);
  ref.watch(publishedPropertiesRealtimeProvider);
  ref.watch(publishedPagesRealtimeProvider);
  ref.watch(partnersRealtimeProvider);
  ref.watch(companyStatsRealtimeProvider);
  ref.watch(clientJourneyRealtimeProvider);
  ref.watch(officeLocationsRealtimeProvider);
  ref.watch(officeDirectoryRealtimeProvider);
  ref.watch(digitalCompanyProfileRealtimeProvider);
  ref.watch(websiteInvestmentOpportunitiesRealtimeProvider);
  ref.watch(websiteInvestmentCategoriesRealtimeProvider);
  ref.watch(websiteMarketInsightsRealtimeProvider);
  ref.watch(websiteConstructionUpdatesRealtimeProvider);
  ref.watch(teamRealtimeProvider);
  ref.watch(propertyListingsRealtimeProvider);
  ref.watch(browseCategoriesRealtimeProvider);
  ref.watch(cmsSeoRealtimeProvider);
  ref.watch(cmsMediaRealtimeProvider);
  ref.watch(testimonialsRealtimeProvider);
  ref.watch(awardsRealtimeProvider);
  ref.watch(bannersRealtimeProvider);
  ref.watch(menusRealtimeProvider);
  ref.watch(footerRealtimeProvider);
  ref.watch(faqRealtimeProvider);
  ref.watch(careersRealtimeProvider);
  ref.watch(calculatorRealtimeProvider);
  ref.watch(roiCalculatorRealtimeProvider);
  ref.watch(servicesCmsRealtimeProvider);
  ref.watch(websiteFormsAdminRealtimeProvider);
  ref.watch(websiteFormsPublicRealtimeProvider);

  // Properties command centers
  ref.watch(adminInspectionsRealtimeProvider);
  ref.watch(adminConsultationsRealtimeProvider);
  ref.watch(adminCallbacksRealtimeProvider);
  ref.watch(callbackPublicRealtimeProvider);
  ref.watch(pmsRealtimeProvider);

  // Identity, compliance, search, AI
  ref.watch(kycRealtimeProvider);
  ref.watch(profileRealtimeProvider);
  ref.watch(enterpriseSearchRealtimeProvider);
  ref.watch(aiWorkspaceRealtimeProvider);

  // Executive dashboard + enterprise modules
  ref.watch(executiveDashboardRealtimeProvider);
  ref.watch(crmRealtimeProvider);
  ref.watch(cpmsRealtimeProvider);
  ref.watch(fapmsRealtimeProvider);
  ref.watch(impRealtimeProvider);
  ref.watch(dxpRealtimeProvider);
  ref.watch(biadwRealtimeProvider);
  ref.watch(ddcmsRealtimeProvider);
  ref.watch(cshopRealtimeProvider);
  ref.watch(eaihRealtimeProvider);
  ref.watch(espRealtimeProvider);
  ref.watch(eipRealtimeProvider);
  ref.watch(sbmsRealtimeProvider);
  ref.watch(organizationRealtimeProvider);
  ref.watch(platformUsersRealtimeProvider);
  ref.watch(rbacRealtimeProvider);
  ref.watch(peopleRbacRealtimeHubProvider);
  ref.watch(auditRealtimeProvider);
  ref.watch(notificationRealtimeProvider);
  ref.watch(adminAnnouncementsRealtimeProvider);
  ref.watch(publicAnnouncementRealtimeProvider);
  ref.watch(personalizationRealtimeProvider);
});
