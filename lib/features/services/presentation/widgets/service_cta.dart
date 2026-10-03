import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/features/services/data/models/service_models.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the link the admin saved on this service.
///
/// No link means there is nothing to open. The catalog does not invent a
/// service detail page.
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

  final path = href.startsWith('/') ? href : '/$href';
  context.go(path);
}
