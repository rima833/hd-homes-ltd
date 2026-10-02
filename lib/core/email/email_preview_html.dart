import 'package:hdhomesproject/core/email/email_models.dart';

/// Builds the same branded HTML the send pipeline wraps around a template,
/// with sample values in place of `{{variables}}`, for the admin preview.
String buildEmailPreviewHtml({
  required String? bodyHtml,
  required String? textBody,
  required EmailBrandConfig brand,
  List<String> variables = const [],
}) {
  final raw = (bodyHtml ?? '').trim().isNotEmpty
      ? bodyHtml!.trim()
      : '<p>${_escape(textBody?.trim().isNotEmpty == true ? textBody!.trim() : 'This template has no content yet.')}</p>';
  final filled = _fillSamples(raw, brand, variables);
  if (filled.toLowerCase().contains('<html')) return filled;
  return _shell(filled, brand);
}

String _fillSamples(String html, EmailBrandConfig brand, List<String> variables) {
  final samples = <String, String>{
    'first_name': 'Adaeze',
    'last_name': 'Nwosu',
    'full_name': 'Adaeze Nwosu',
    'name': 'Adaeze Nwosu',
    'email': 'adaeze@example.com',
    'cta_url': brand.websiteUrl,
    'action_url': brand.websiteUrl,
    'confirmation_url': brand.websiteUrl,
    'company_name': brand.companyName,
    'support_email': brand.supportEmail,
  };
  for (final key in variables) {
    samples.putIfAbsent(key, () => key.replaceAll('_', ' '));
  }
  return html.replaceAllMapped(RegExp(r'\{\{\s*([a-zA-Z0-9_.]+)\s*\}\}'), (match) {
    final key = match.group(1) ?? '';
    return _escape(samples[key] ?? key.replaceAll('_', ' '));
  });
}

String _shell(String contentHtml, EmailBrandConfig brand) {
  final gold = _escape(
    brand.primaryColor.trim().isEmpty ? '#d6a847' : brand.primaryColor.trim(),
  );
  final logo = brand.logoUrl.trim().isEmpty
      ? ''
      : '<img src="${_escape(brand.logoUrl)}" alt="${_escape(brand.companyName)}" width="95" style="display:block;max-width:95px;height:auto;margin:0 auto;border:0;outline:none;" />';
  return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${_escape(brand.companyName)}</title>
</head>
<body style="margin:0;padding:0;background:#f3f4f6;font-family:Arial,Helvetica,sans-serif;color:#1a1a1a;">
<table width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#f3f4f6;">
  <tr>
    <td align="center" style="padding:28px 12px;">
      <table width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:620px;background:#ffffff;border-radius:16px;overflow:hidden;border:1px solid #e5e7eb;">
        <tr>
          <td align="center" style="background:#111111;padding:32px 25px 28px;">
            $logo
            <p style="margin:14px 0 0;font-size:11px;letter-spacing:2.5px;color:$gold;font-weight:bold;">HD HOMES LIMITED</p>
          </td>
        </tr>
        <tr>
          <td style="height:4px;background:$gold;font-size:0;line-height:0;">&nbsp;</td>
        </tr>
        <tr>
          <td style="padding:36px 32px 32px;">
            $contentHtml
          </td>
        </tr>
        <tr>
          <td style="padding:0 32px;"><div style="height:1px;background:#eeeeee;"></div></td>
        </tr>
        <tr>
          <td align="center" style="padding:24px 24px 28px;background:#ffffff;">
            <p style="margin:0 0 8px;font-size:14px;font-weight:bold;color:#222222;">${_escape(brand.companyName)}</p>
            <p style="margin:0 0 14px;font-size:12px;line-height:1.6;color:#8a8a8a;">${_escape(brand.tagline)}</p>
            <p style="margin:0;font-size:11px;line-height:1.6;color:#a0a0a0;">Preview only. Customers receive this inside the HD Homes email.</p>
          </td>
        </tr>
      </table>
    </td>
  </tr>
</table>
</body>
</html>''';
}

String _escape(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
