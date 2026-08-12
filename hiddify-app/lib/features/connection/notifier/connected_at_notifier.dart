import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Wall-clock moment the current connection was established, null when the
/// tunnel is down. Drives the home page uptime chip.
final connectedAtProvider = NotifierProvider<ConnectedAtNotifier, DateTime?>(ConnectedAtNotifier.new);

class ConnectedAtNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() {
    ref.listen(connectionNotifierProvider, (previous, next) {
      final wasConnected = previous?.valueOrNull?.isConnected ?? false;
      final isConnected = next.valueOrNull?.isConnected ?? false;
      if (isConnected && !wasConnected) {
        state = DateTime.now();
      } else if (!isConnected && state != null) {
        state = null;
      }
    });
    final connected = ref.read(connectionNotifierProvider).valueOrNull?.isConnected ?? false;
    return connected ? DateTime.now() : null;
  }
}
