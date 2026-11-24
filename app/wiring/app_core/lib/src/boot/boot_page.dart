import 'package:app_core/src/boot/boot_state.dart';
import 'package:flutter/material.dart';
import 'package:mc_ds_feedback/mc_ds_feedback.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';

/// What the app shows until boot is ready (Tide's BootPage, D-21).
///
/// Strings are English until `mc_l10n_core` exists.
class BootPage extends StatelessWidget {
  const BootPage({
    required this.state,
    required this.onRetry,
    this.title = 'Mini Client',
    super.key,
  });

  static const loadingKey = Key('boot.loading');
  static const failedKey = Key('boot.failed');
  static const timedOutKey = Key('boot.timedOut');

  final BootState state;
  final VoidCallback onRetry;
  final String title;

  @override
  Widget build(BuildContext context) {
    final body = switch (state) {
      BootFailed(:final error) => McErrorView(
        key: failedKey,
        title: 'Could not start',
        message: _describe(error),
        onRetry: onRetry,
      ),
      BootTimedOut(:final timeout) => McErrorView(
        key: timedOutKey,
        title: 'Taking too long',
        message: 'Start-up did not finish within ${timeout.inSeconds} s.',
        onRetry: onRetry,
      ),
      BootBooting() || BootReady() => Column(
        key: loadingKey,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const McGap.lg(),
          const McLoading(semanticLabel: 'Starting'),
        ],
      ),
    };
    return Scaffold(
      body: SafeArea(child: Center(child: body)),
    );
  }

  static String _describe(Object error) {
    final text = error.toString();
    return text.length > 200 ? '${text.substring(0, 200)}…' : text;
  }
}
