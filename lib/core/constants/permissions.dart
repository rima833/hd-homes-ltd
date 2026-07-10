/// Permission slugs — must match Supabase `permissions` table.
abstract final class PermissionSlugs {
  static const viewProperties = 'view_properties';
  static const createProperty = 'create_property';
  static const editProperty = 'edit_property';
  static const deleteProperty = 'delete_property';
  static const publishProperty = 'publish_property';
  static const manageUsers = 'manage_users';
  static const manageRoles = 'manage_roles';
  static const managePayments = 'manage_payments';
  static const manageBlog = 'manage_blog';
  static const manageMarketing = 'manage_marketing';
  static const manageConstruction = 'manage_construction';
  static const manageCrm = 'manage_crm';
  static const manageReports = 'manage_reports';
  static const manageSettings = 'manage_settings';
}
