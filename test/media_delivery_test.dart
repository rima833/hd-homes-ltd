import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/media/media_delivery.dart';

void main() {
  group('MediaDelivery', () {
    test('prefers secure_url over file_url', () {
      expect(
        MediaDelivery.resolve(
          secureUrl: 'https://res.cloudinary.com/demo/image/upload/v1/a.jpg',
          fileUrl: 'https://old.supabase.co/storage/v1/object/public/x.jpg',
        ),
        'https://res.cloudinary.com/demo/image/upload/v1/a.jpg',
      );
    });

    test('falls back to file_url when secure_url empty', () {
      expect(
        MediaDelivery.resolve(
          secureUrl: '',
          fileUrl: 'https://old.supabase.co/storage/v1/object/public/x.jpg',
        ),
        'https://old.supabase.co/storage/v1/object/public/x.jpg',
      );
    });

    test('adds f_auto q_auto transforms to cloudinary urls', () {
      const url =
          'https://res.cloudinary.com/demo/image/upload/v123/sample.jpg';
      final out = MediaDelivery.transform(url, width: 400);
      expect(out, contains('f_auto'));
      expect(out, contains('q_auto'));
      expect(out, contains('w_400'));
    });

    test('leaves non-cloudinary urls unchanged', () {
      const url = 'https://example.com/photo.jpg';
      expect(MediaDelivery.transform(url, width: 400), url);
    });

    test('detects cloudinary video urls', () {
      expect(
        MediaDelivery.isVideoUrl(
          'https://res.cloudinary.com/demo/video/upload/v1/sample.mp4',
        ),
        isTrue,
      );
      expect(MediaDelivery.isVideoUrl('https://example.com/photo.jpg'), isFalse);
    });
  });
}
