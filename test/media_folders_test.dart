import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/media/media_folders.dart';
import 'package:hdhomesproject/core/media/media_models.dart';

void main() {
  group('MediaFolders', () {
    test('resolves property gallery path under hdhomes root', () {
      expect(
        MediaFolders.resolve(
          entityType: MediaEntityType.property,
          entityId: 'prop-1',
          role: MediaFolderRole.gallery,
        ),
        'hdhomes/properties/prop-1/gallery',
      );
    });

    test('resolves blog featured path', () {
      expect(
        MediaFolders.resolve(
          entityType: MediaEntityType.blog,
          entityId: 'blog-1',
          role: MediaFolderRole.featured,
        ),
        'hdhomes/blog/blog-1/featured',
      );
    });

    test('resolves user avatar path', () {
      expect(
        MediaFolders.resolve(
          entityType: MediaEntityType.user,
          entityId: 'user-1',
          role: MediaFolderRole.avatar,
        ),
        'hdhomes/users/user-1/avatar',
      );
    });

    test('explicit folder on request wins', () {
      const request = UploadMediaRequest(
        bytes: [1],
        contentType: 'image/jpeg',
        originalFilename: 'a.jpg',
        folder: 'hdhomes/general/website/inbox',
      );
      expect(
        MediaFolders.resolveFromRequest(request),
        'hdhomes/general/website/inbox',
      );
    });
  });
}
