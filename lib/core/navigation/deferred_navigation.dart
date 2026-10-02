import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Navigate after the current frame so heavy page teardown (Contact Hub,
/// booking wizards, live chat) does not run mid-gesture and freeze the UI.
void goDeferred(BuildContext context, String location) {
  final router = GoRouter.maybeOf(context);
  if (router == null) return;
  SchedulerBinding.instance.addPostFrameCallback((_) {
    router.go(location);
  });
}
