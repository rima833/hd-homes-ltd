import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_blog_admin_page.dart';

void main() {
  group('blogPublishValidationError', () {
    test('requires title and slug', () {
      expect(
        blogPublishValidationError(
          title: '',
          slug: 'a-post',
          coverImageUrl: 'https://example.com/cover.jpg',
          publish: false,
        ),
        'Title and slug are required.',
      );
    });

    test('allows draft without a cover image', () {
      expect(
        blogPublishValidationError(
          title: 'A post',
          slug: 'a-post',
          coverImageUrl: '',
          publish: false,
        ),
        isNull,
      );
    });

    test('blocks publish without a cover image', () {
      expect(
        blogPublishValidationError(
          title: 'A post',
          slug: 'a-post',
          coverImageUrl: '  ',
          publish: true,
        ),
        'Add a cover image before publishing.',
      );
    });

    test('allows publish with a cover image', () {
      expect(
        blogPublishValidationError(
          title: 'A post',
          slug: 'a-post',
          coverImageUrl: 'https://example.com/cover.jpg',
          publish: true,
        ),
        isNull,
      );
    });
  });

  test('CmsBlogPost.fromJson keeps cover image and body', () {
    final post = CmsBlogPost.fromJson({
      'id': '11111111-1111-4111-8111-111111111111',
      'title': 'Covered post',
      'slug': 'covered-post',
      'excerpt': 'Short excerpt',
      'cover_image_url': 'https://images.example.com/home.jpg',
      'content': {'body': '## Heading\n\nFull article body.'},
      'is_published': true,
      'featured': true,
      'status': 'published',
    });

    expect(post.coverImageUrl, 'https://images.example.com/home.jpg');
    expect(post.body, contains('Full article body'));
    expect(post.isPublished, isTrue);
  });
}
