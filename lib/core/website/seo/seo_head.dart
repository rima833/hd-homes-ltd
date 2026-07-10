import 'package:hdhomesproject/core/website/seo/seo_metadata.dart';

import 'seo_head_stub.dart' if (dart.library.html) 'seo_head_web.dart';

/// Applies [SeoMetadata] to the browser document head (web only).
abstract final class SeoHead {
  static void apply(SeoMetadata metadata) => applySeoHead(metadata);
}
