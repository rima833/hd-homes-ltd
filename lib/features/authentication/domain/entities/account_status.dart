/// Account status aligned with Postgres `public.account_status`.
enum AccountStatus {
  pendingVerification('pending_verification'),
  active('active'),
  inactive('inactive'),
  suspended('suspended'),
  deleted('deleted');

  const AccountStatus(this.slug);
  final String slug;

  static AccountStatus fromSlug(String? value) {
    if (value == null) return AccountStatus.pendingVerification;
    for (final status in AccountStatus.values) {
      if (status.slug == value) return status;
    }
    return AccountStatus.pendingVerification;
  }
}
