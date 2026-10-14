// Regenerates web/robots.txt and the static portion of web/sitemap.xml.
//
// Usage (from repo root):
//   dart run tool/generate_seo_artifacts.dart
//
// Optional: pass dynamic URL lines (one absolute URL per line) via stdin or
// `--urls=path/to/extra-urls.txt` for property/blog/estate rows from CI.

import 'dart:io';

import 'package:hdhomesproject/core/growth/seo/seo_engine.dart';

Future<void> main(List<String> args) async {
  final webDir = Directory('web');
  if (!await webDir.exists()) {
    stderr.writeln('web/ directory not found — run from project root.');
    exitCode = 1;
    return;
  }

  final extraUrls = await _readExtraUrls(args);
  final robots = File('web/robots.txt');
  final sitemap = File('web/sitemap.xml');

  await robots.writeAsString('${SeoEngine.robotsTxt()}\n');
  await sitemap.writeAsString('${SeoEngine.sitemapXml(extraUrls: extraUrls)}\n');

  stdout.writeln(
    'Wrote web/robots.txt and web/sitemap.xml '
    '(${SeoEngine.sitemapUrls().length + extraUrls.length} URLs).',
  );
}

Future<List<String>> _readExtraUrls(List<String> args) async {
  for (final arg in args) {
    if (arg.startsWith('--urls=')) {
      final path = arg.substring('--urls='.length);
      final file = File(path);
      if (!await file.exists()) return const [];
      return file
          .readAsLinesSync()
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && l.startsWith('http'))
          .toList();
    }
  }
  return const [];
}
