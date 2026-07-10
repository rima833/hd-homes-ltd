/// HD Homes platform role slugs (matches Supabase `roles` table).
enum AppRole {
  superAdmin('super_admin'),
  admin('admin'),
  salesTeam('sales_team'),
  finance('finance'),
  marketing('marketing'),
  constructionManager('construction_manager'),
  client('client');

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
        AppRole.client => false,
      };

  bool get canAccessDashboard => switch (this) {
        AppRole.superAdmin || AppRole.admin => true,
        _ => false,
      };

  String get defaultRoute => switch (this) {
        AppRole.superAdmin || AppRole.admin => '/dashboard',
        AppRole.client => '/client',
        AppRole.finance ||
        AppRole.salesTeam ||
        AppRole.marketing ||
        AppRole.constructionManager =>
          '/dashboard',
      };
}
