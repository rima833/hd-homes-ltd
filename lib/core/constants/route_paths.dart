/// Centralized route path constants for GoRouter.
abstract final class RoutePaths {
  // ── Public website ──────────────────────────────────────────────────────
  static const home = '/';
  static const about = '/about';
  static const properties = '/properties';
  static const propertyDetails = '/properties/:id';
  static const paymentCalculator = '/properties/payment-calculator';
  static const estates = '/estates';
  static const estateDetails = '/estates/:slug';
  static const investment = '/investment';
  static String investmentOpportunity(String slug) => '/investment/$slug';
  static const roiCalculator = '/investment/roi-calculator';
  static const dashboardWebsiteInvestments = '/dashboard/website/investments';
  static const dashboardWebsiteMarketInsights =
      '/dashboard/website/market-insights';
  static const services = '/services';
  static const serviceDetails = '/services/:slug';
  static String serviceDetail(String slug) => '/services/$slug';
  /// Parent key for the public "Discover" mega-menu (not a standalone page).
  static const discover = '/discover';
  static const blog = '/blog';
  static const blogPost = '/blog/:slug';
  static const gallery = '/gallery';
  static const construction = '/construction';
  static String constructionProgress(String slug) => '/construction/$slug';
  static const dashboardWebsiteConstruction = '/dashboard/website/construction';
  static const trust = '/trust';
  static const careers = '/careers';
  static const contact = '/contact';
  static const bookInspection = '/book-inspection';
  static const bookConsultation = '/book-consultation';
  static const search = '/search';
  static const cmsPage = '/pages/:slug';
  static String cmsPagePath(String slug) => '/pages/$slug';
  /// Marketing campaign landing pages (`landing_pages` table).
  static const landingPage = '/lp/:slug';
  static String landingPagePath(String slug) => '/lp/$slug';

  // ── Authentication (standalone, no shell) ─────────────────────────────────
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const verifyEmail = '/verify-email';
  static const authCallback = '/auth/callback';
  static const welcome = '/welcome';
  static const activeSessions = '/account/sessions';
  static const verificationCenter = '/account/verification';
  static const verifyPhone = '/account/verify-phone';
  static const securityCenter = '/account/security';
  static const profileCenter = '/account/profile';
  static const preferenceCenter = '/account/preferences';
  static const accessibilityCenter = '/account/accessibility';
  static const staffOnboarding = '/account/staff-onboarding';
  static const kycVerification = '/account/kyc';
  static const kycCompliance = '/dashboard/compliance';
  static const notificationCenter = '/account/notifications';
  static const activityTimeline = '/account/activity';
  static const personalizationAnalytics = '/dashboard/personalization';
  static const searchInsights = '/dashboard/search';
  static const aiWorkspace = '/account/ai';
  static const aiGovernance = '/dashboard/ai';
  static const adminCommunications = '/dashboard/communications';
  static const mfaSetup = '/account/mfa/setup';
  static const mfaChallenge = '/mfa/challenge';

  // ── Admin dashboard (streamlined control center) ────────────────────────
  static const dashboard = '/dashboard';
  static const dashboardSupport = '/dashboard/support';
  static const dashboardLiveChat = '/dashboard/live-chat';
  static const dashboardDocuments = '/dashboard/documents';
  static const dashboardWebsite = '/dashboard/website';
  static const dashboardWebsiteHomepage = '/dashboard/website/homepage';
  static const dashboardWebsiteHero = '/dashboard/website/hero';
  static const dashboardWebsitePages = '/dashboard/website/pages';
  static const dashboardWebsiteFeaturedEstates =
      '/dashboard/website/featured-estates';
  static const dashboardWebsiteFeaturedProperties =
      '/dashboard/website/featured-properties';
  static const dashboardWebsiteTestimonials = '/dashboard/website/testimonials';
  static const dashboardWebsiteAwards = '/dashboard/website/awards';
  static const dashboardWebsitePartners = '/dashboard/website/partners';
  static const dashboardWebsiteStatistics = '/dashboard/website/statistics';
  static const dashboardWebsiteClientJourney =
      '/dashboard/website/client-journey';
  static const dashboardWebsiteJourneyBenefits =
      '/dashboard/website/journey-benefits';
  static const dashboardWebsiteOffices = '/dashboard/website/offices';
  static const dashboardWebsiteDigitalProfile =
      '/dashboard/website/digital-profile';
  static const dashboardWebsiteCareers = '/dashboard/website/careers';
  static const dashboardWebsiteSupport = '/dashboard/website/support';
  static const dashboardWebsitePartnerships = '/dashboard/website/partnerships';
  static const dashboardWebsiteServices = '/dashboard/website/services';
  static const dashboardWebsiteBrowseCategories =
      '/dashboard/website/browse-categories';
  static const dashboardWebsitePaymentCalculator =
      '/dashboard/website/payment-calculator';
  static const dashboardWebsiteRoiCalculator =
      '/dashboard/website/roi-calculator';
  static const dashboardWebsiteTeam = '/dashboard/website/team';
  static const dashboardWebsiteFaq = '/dashboard/website/faq';
  static const dashboardWebsiteBlog = '/dashboard/website/blog';
  static const dashboardWebsiteBanners = '/dashboard/website/banners';
  static const dashboardWebsiteMenus = '/dashboard/website/menus';
  static const dashboardWebsiteFooter = '/dashboard/website/footer';
  static const dashboardWebsiteMedia = '/dashboard/website/media';
  static const dashboardWebsiteSeo = '/dashboard/website/seo';
  static const dashboardWebsiteCompany = '/dashboard/website/company';

  /// Legacy aliases (still routed) — prefer website/* paths above.
  static const dashboardBanners = '/dashboard/banners';
  static const dashboardSeo = '/dashboard/seo';
  static const dashboardProperties = '/dashboard/properties';
  static const dashboardInspections = '/dashboard/inspections';
  static const dashboardConsultations = '/dashboard/consultations';
  static const dashboardCallbacks = '/dashboard/callbacks';
  static const dashboardPropertyUnits = '/dashboard/properties/units';
  static const dashboardPropertyTypes = '/dashboard/properties/types';
  static const dashboardPropertyCategories = '/dashboard/properties/categories';
  static const dashboardPropertyAmenities = '/dashboard/properties/amenities';
  static const dashboardPropertyPricing = '/dashboard/properties/pricing';
  static const dashboardPropertyAvailability =
      '/dashboard/properties/availability';
  static const dashboardEstates = '/dashboard/estates';
  static const dashboardClients = '/dashboard/clients';
  static const dashboardInvestors = '/dashboard/investors';
  static const dashboardCrm = '/dashboard/crm';
  static const dashboardClientApplications = '/dashboard/client-applications';
  static const dashboardConstruction = '/dashboard/construction';
  static const dashboardFinance = '/dashboard/finance';
  static const dashboardMarketing = '/dashboard/marketing';
  static const dashboardBlog = '/dashboard/blog';
  static const dashboardMedia = '/dashboard/media';
  static const dashboardReports = '/dashboard/reports';
  static const dashboardAnalytics = '/dashboard/analytics';
  static const dashboardUsers = '/dashboard/users';
  static const dashboardOrganization = '/dashboard/organization';
  static const dashboardRoles = '/dashboard/roles';
  static const dashboardPlatformUsers = '/dashboard/platform-users';
  static const dashboardSettings = '/dashboard/settings';
  static const dashboardActivityLogs = '/dashboard/activity-logs';
  static const dashboardProfile = '/dashboard/profile';

  // ── Client portal ───────────────────────────────────────────────────────
  static const client = '/client';
  static const clientProperties = '/client/properties';
  static const clientApplications = '/client/applications';
  static String clientApplicationDetail(String id) => '/client/applications/$id';
  static const clientSaved = '/client/saved';
  static const clientPayments = '/client/payments';
  static const clientDocuments = '/client/documents';
  static const clientConstruction = '/client/construction';
  static const clientInspections = '/client/inspections';
  static const clientConsultations = '/client/consultations';
  static const clientMessages = '/client/messages';
  static String clientMessagesLive() => '$clientMessages?live=1';
  static const clientNotifications = '/client/notifications';
  static const clientSupport = '/client/support';
  static const clientReferrals = '/client/referrals';
  static const clientSettings = '/client/settings';
  static const clientMore = '/client/more';
  static const clientTools = '/client/tools';
  static String clientPropertyDetail(String propertyId) =>
      '$clientProperties/$propertyId';

  // ── Investor portal ─────────────────────────────────────────────────────
  static const investor = '/investor';
  static const investorPortfolio = '/investor/portfolio';
  static const investorAnalytics = '/investor/analytics';
  static const investorConstruction = '/investor/construction';
  static const investorReports = '/investor/reports';
  static const investorPayments = '/investor/payments';
  static const investorDocuments = '/investor/documents';
  static const investorReferrals = '/investor/referrals';
  static const investorMessages = '/investor/messages';
  static String investorMessagesLive() => '$investorMessages?live=1';
  static const investorNotifications = '/investor/notifications';
  static const investorSupport = '/investor/support';
  static const investorSettings = '/investor/settings';
  static const investorMore = '/investor/more';
  static const investorTools = '/investor/tools';
  static String investorHoldingDetail(String holdingId) =>
      '$investorPortfolio/$holdingId';

  static const protectedPrefixes = [dashboard, client, investor, '/account'];

  static const authRoutes = [
    login,
    register,
    forgotPassword,
    resetPassword,
    verifyEmail,
    authCallback,
    welcome,
    mfaSetup,
    mfaChallenge,
  ];
}

