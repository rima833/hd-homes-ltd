/// Canonical HD Homes brand copy shared by homepage About and /about.
///
/// Keep mission, vision, story, and core values identical across surfaces so
/// "Learn More" / About nav never diverge from the homepage teaser.
abstract final class BrandCopy {
  static const companyName = 'HD Homes Ltd';

  static const aboutTitle = 'Building More Than Properties,';
  static const aboutTitleAccent = 'We Build Trust.';

  static const story =
      'HD Homes Ltd is a premium property developer committed to making '
      'quality housing accessible through innovation, transparency, and '
      'world-class construction.';

  static const mission =
      'Our mission is to be the top best in providing quality homes and real '
      'estate investment at best value and to ensure we produce 1,000 home '
      'owners in 5 years.';

  static const vision =
      'Making quality housing accessible to our client individually and '
      'through partnership.';

  static const philosophy =
      'We believe every family deserves a home built with integrity, and '
      'every investor deserves clarity from day one.';

  static const heroHeadline =
      'Building Homes.\nCreating Communities.\nInspiring Futures.';

  static const heroHeadlineFlat =
      'Building Homes. Creating Communities. Inspiring Futures.';

  static const heroSubheadline =
      'HD Homes Ltd is a premium Nigerian property developer delivering '
      'trusted homes, estates, and investment opportunities with transparency '
      'and excellence.';

  /// Core values shown on the homepage About teaser.
  static const coreValueLabels = [
    'Integrity',
    'Energy',
    'Innovation',
    'Drive',
    'Commitment',
  ];

  /// Official HD Homes core values (title → subtitle + body + icon).
  static const coreValues = <BrandCoreValue>[
    BrandCoreValue(
      title: 'Integrity',
      subtitle: 'Honor our commitment to those we serve.',
      description:
          'We don\'t take our commitments lightly, we do everything within '
          'our power to meet expectations. We own up to and learn from our '
          'mistakes. We do the right thing always no matter how hard.',
      iconName: 'handshake',
    ),
    BrandCoreValue(
      title: 'Energy',
      subtitle: 'Positive energy brings positive result.',
      description:
          'We align our actions with our goals. We put in the right and '
          'consistent energy to bring about positive result. We are proactive '
          'and strive to achieve our goals.',
      iconName: 'zap',
    ),
    BrandCoreValue(
      title: 'Innovation',
      subtitle: 'We are curious, adventurous and creative.',
      description:
          'We question conventional wisdom and challenge the status quo. If '
          'there is a better way we will find it. We are excited by ingenuity '
          'and thrilled to try something new.',
      iconName: 'lightbulb',
    ),
    BrandCoreValue(
      title: 'Drive',
      subtitle: 'We are never satisfied with good enough.',
      description:
          'Excellence is a habit not a goal. We welcome a challenge with '
          'enthusiasm and go above and beyond the call of duty because it\'s '
          'who we are.',
      iconName: 'clipboard_check',
    ),
    BrandCoreValue(
      title: 'Commitment',
      subtitle: 'Passion for service',
      description:
          'We are dedicated to stellar effort, positive attitude and high '
          'performance.',
      iconName: 'handshake',
    ),
  ];

  /// Short blurbs for surfaces that only show one line per value.
  static Map<String, String> get valueDescriptions => {
        for (final value in coreValues) value.title: value.subtitle,
      };
}

class BrandCoreValue {
  const BrandCoreValue({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.iconName,
  });

  final String title;
  final String subtitle;
  final String description;
  final String iconName;
}
