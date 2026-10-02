import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/utils/provider_lifecycle.dart';

void main() {
  test('cross-provider writes run after provider initialization', () async {
    final target = StateProvider<int>((ref) => 0);
    final source = Provider<void>((ref) {
      deferProviderMutation(() {
        ref.read(target.notifier).state = 1;
      });
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(source);
    expect(container.read(target), 0);

    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(container.read(target), 1);
  });

  test('a deferred write is harmless after container disposal', () async {
    final target = StateProvider<int>((ref) => 0);
    final source = Provider<void>((ref) {
      deferProviderMutation(() {
        ref.read(target.notifier).state = 1;
      });
    });
    final container = ProviderContainer();

    container.read(source);
    container.dispose();

    await Future<void>.delayed(const Duration(milliseconds: 10));
  });
}
