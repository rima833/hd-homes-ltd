/// Centralized route path constants for GoRouter.
abstract final class RoutePaths {
  // ── Public website ──────────────────────────────────────────────────────
  static const home = '/';
  static const about = '/about';
  static const properties = '/properties';
  static const propertyDetails = '/properties/:id';
  static const estates = '/estates';
  static const estateDetails = '/estates/:slug';
  static const investment = '/investment';
  static const services = '/services';
  static const serviceDetails = '/services/:slug';
  static const blog = '/blog';
  static const blogPost = '/blog/:slug';
  static const gallery = '/gallery';
  static const trust = '/trust';
  static const careers = '/careers';
  static const contact = '/contact';
  static const bookInspection = '/book-inspection';
  static const search = '/search';

  // ── Authentication (standalone, no shell) ─────────────────────────────────
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';

  // ── Admin dashboard ─────────────────────────────────────────────────────
  static const dashboard = '/dashboard';
  static const dashboardWebsite = '/dashboard/website';
  static const dashboardBanners = '/dashboard/banners';
  static const dashboardSeo = '/dashboard/seo';
  static const dashboardProperties = '/dashboard/properties';
  static const dashboardEstates = '/dashboard/estates';
  static const dashboardClients = '/dashboard/clients';
  static const dashboardInvestors = '/dashboard/investors';
  static const dashboardCrm = '/dashboard/crm';
  static const dashboardConstruction = '/dashboard/construction';
  static const dashboardFinance = '/dashboard/finance';
  static const dashboardMarketing = '/dashboard/marketing';
  static const dashboardBlog = '/dashboard/blog';
  static const dashboardMedia = '/dashboard/media';
  static const dashboardReports = '/dashboard/reports';
  static const dashboardAnalytics = '/dashboard/analytics';
  static const dashboardNotifications = '/dashboard/notifications';
  static const dashboardUsers = '/dashboard/users';
  static const dashboardRoles = '/dashboard/roles';
  static const dashboardSettings = '/dashboard/settings';
  static const dashboardActivityLogs = '/dashboard/activity-logs';
  static const dashboardProfile = '/dashboard/profile';

  // ── Client portal ───────────────────────────────────────────────────────
  static const client = '/client';
  static const clientProperties = '/client/properties';
  static const clientSaved = '/client/saved';
  static const clientPayments = '/client/payments';
  static const clientDocuments = '/client/documents';
  static const clientConstruction = '/client/construction';
  static const clientInspections = '/client/inspections';
  static const clientMessages = '/client/messages';
  static const clientNotifications = '/client/notifications';
  static const clientSupport = '/client/support';
  static const clientReferrals = '/client/referrals';
  static const clientSettings = '/client/settings';

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
  static const investorNotifications = '/investor/notifications';
  static const investorSupport = '/investor/support';
  static const investorSettings = '/investor/settings';

  static const protectedPrefixes = [dashboard, client, investor];

  static const authRoutes = [login, register, forgotPassword];
}
