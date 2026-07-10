/// Animation duration tokens (250–400ms page transitions).
abstract final class AppDurations {
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration pageTransition = Duration(milliseconds: 350);
}
