import 'dart:convert';

import 'package:hdhomesproject/core/website/seo/seo_metadata.dart';
import 'package:web/web.dart' as web;

/// Updates document `<head>` meta tags for Flutter web.
void applySeoHead(SeoMetadata metadata) {
  web.document.title = metadata.title;

  _setMetaName('description', metadata.description);
  _setMetaName('robots', metadata.robots);

  if (metadata.keywords.isNotEmpty) {
    _setMetaName('keywords', metadata.keywords.join(', '));
  }

  _setMetaProperty('og:title', metadata.title);
  _setMetaProperty('og:description', metadata.description);
  _setMetaProperty('og:type', 'website');
  _setMetaName('twitter:card', 'summary_large_image');
  _setMetaName('twitter:title', metadata.title);
  _setMetaName('twitter:description', metadata.description);

  if (metadata.ogImageUrl != null) {
    _setMetaProperty('og:image', metadata.ogImageUrl!);
    _setMetaName('twitter:image', metadata.ogImageUrl!);
  }

  if (metadata.canonicalUrl != null) {
    _setLink('canonical', metadata.canonicalUrl!);
  }

  _setJsonLd(metadata.structuredData);
}

void _setMetaName(String name, String content) {
  final selector = 'meta[name="$name"]';
  var element = web.document.querySelector(selector);
  if (element == null) {
    final meta = web.document.createElement('meta') as web.HTMLMetaElement;
    meta.name = name;
    web.document.head!.append(meta);
    element = meta;
  }
  (element as web.HTMLMetaElement).content = content;
}

void _setMetaProperty(String property, String content) {
  final selector = 'meta[property="$property"]';
  var element = web.document.querySelector(selector);
  if (element == null) {
    final meta = web.document.createElement('meta') as web.HTMLMetaElement;
    meta.setAttribute('property', property);
    web.document.head!.append(meta);
    element = meta;
  }
  (element as web.HTMLMetaElement).content = content;
}

void _setLink(String rel, String href) {
  final selector = 'link[rel="$rel"]';
  var element = web.document.querySelector(selector);
  if (element == null) {
    final link = web.document.createElement('link') as web.HTMLLinkElement;
    link.rel = rel;
    web.document.head!.append(link);
    element = link;
  }
  (element as web.HTMLLinkElement).href = href;
}

void _setJsonLd(Map<String, dynamic>? data) {
  const id = 'hdhomes-json-ld';
  final existing = web.document.getElementById(id);
  existing?.remove();

  if (data == null) return;

  final script = web.document.createElement('script') as web.HTMLScriptElement;
  script.id = id;
  script.type = 'application/ld+json';
  script.text = jsonEncode(data);
  web.document.head!.append(script);
}
