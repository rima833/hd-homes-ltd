/// HD Homes platform role slugs (matches Supabase `roles` table).
enum AppRole {
  superAdmin('super_admin'),
  admin('admin'),
  salesTeam('sales_team'),
  finance('finance'),
  marketing('marketing'),
  constructionManager('construction_manager'),
  client('client'),
  investor('investor');

  const AppRole(this.slug);
  final String slug;

  static AppRole? fromSlug(String? slug) {
    if (slug == null) return null;
    for (final role in AppRole.values) {
      if (role.slug == slug) return role;
    }
    return null;
  }

  bool get isStaff => switch (this) {
        AppRole.superAdmin ||
        AppRole.admin ||
        AppRole.salesTeam ||
        AppRole.finance ||
        AppRole.marketing ||
        AppRole.constructionManager =>
          true,
        AppRole.client || AppRole.investor => false,
      };

  bool get canAccessDashboard => switch (this) {
        AppRole.superAdmin || AppRole.admin => true,
        AppRole.finance ||
        AppRole.salesTeam ||
        AppRole.marketing ||
        AppRole.constructionManager =>
          true,
        _ => false,
      };

  bool get canAccessInvestorPortal => switch (this) {
        AppRole.investor ||
        AppRole.client ||
        AppRole.superAdmin ||
        AppRole.admin ||
        AppRole.finance =>
          true,
        _ => false,
      };

  bool get canAccessClientPortal => switch (this) {
        AppRole.client ||
        AppRole.investor ||
        AppRole.superAdmin ||
        AppRole.admin ||
        AppRole.salesTeam =>
          true,
        _ => false,
      };

  String get defaultRoute => switch (this) {
        AppRole.superAdmin || AppRole.admin => '/dashboard',
        AppRole.finance ||
        AppRole.salesTeam ||
        AppRole.marketing ||
        AppRole.constructionManager =>
          '/dashboard',
        AppRole.investor => '/investor',
        AppRole.client => '/client',
      };

  String get displayName => switch (this) {
        AppRole.superAdmin => 'Super Admin',
        AppRole.admin => 'Admin',
        AppRole.salesTeam => 'Sales Team',
        AppRole.finance => 'Finance',
        AppRole.marketing => 'Marketing',
        AppRole.constructionManager => 'Construction Manager',
        AppRole.client => 'Client',
        AppRole.investor => 'Investor',
      };
}
