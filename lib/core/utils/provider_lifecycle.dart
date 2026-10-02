import 'dart:async';

/// Runs a cross-provider mutation on the next event-loop turn.
///
/// External SDK callbacks (notably Supabase Realtime) may fire synchronously
/// while Riverpod is still initializing or disposing a provider. Mutating a
/// different provider in that stack violates Riverpod's lifecycle contract.
void deferProviderMutation(void Function() mutation) {
  Timer.run(() {
    try {
      mutation();
    } catch (_) {
      // The owning provider/container may have been disposed before this turn.
    }
  });
}
