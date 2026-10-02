import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/services/data/models/service_models.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a service CTA without freezing the public shell.
///
/// Default destination is `/services/{slug}`. Admin can override via
/// [ServiceSummary.ctaHref] (internal path or absolute URL).
Future<void> openServiceLearnMore(
  BuildContext context,
  ServiceSummary service,
) async {
  final href = service.resolvedCtaHref;
  if (href.isEmpty) return;

  final uri = Uri.tryParse(href);
  final isExternal = uri != null &&
      uri.hasScheme &&
      (uri.scheme == 'http' || uri.scheme == 'https');

  if (isExternal) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return;
  }

  if (!context.mounted) return;

  // Prefer go_router path navigation. Use go (not push) so /services/:slug
  // replaces the catalog cleanly inside PublicShell without stacking shells.
  final path = href.startsWith('/') ? href : '/$href';
  try {
    context.go(path);
  } catch (_) {
    // Fallback to the canonical detail route when a custom path is invalid.
    if (context.mounted) {
      context.go(RoutePaths.serviceDetail(service.slug));
    }
  }
}
