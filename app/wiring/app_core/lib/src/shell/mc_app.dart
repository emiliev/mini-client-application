import 'dart:async';

import 'package:app_core/src/boot/boot_bloc.dart';
import 'package:app_core/src/boot/boot_page.dart';
import 'package:app_core/src/boot/boot_state.dart';
import 'package:app_core/src/links/pending_links.dart';
import 'package:app_core/src/router/router_ref.dart';
import 'package:app_core/src/shell/route_probe.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_monitoring/mc_monitoring.dart';

/// Builds the app's router once boot is ready, starting at
/// [initialLocation] (the held deep link, or `/`).
typedef McRouterFactory = GoRouter Function(String initialLocation);

/// The app shell (plan 01 §3.4, R29).
///
/// While boot is not ready it renders `MaterialApp` with [BootPage] only: no
/// `GoRouter` exists, so no route builder, `redirect` or navigator runs. On
/// `ready` it creates the router once, with the link [links] held as
/// `initialLocation`, and switches to `MaterialApp.router`. [links] stays
/// attached until that frame has built the router (so a link arriving in
/// between never reaches the dying boot navigator); then it detaches, later
/// links go to go_router, and a link caught in the gap is forwarded.
class McApp extends StatefulWidget {
  const McApp({
    required this.boot,
    required this.router,
    required this.links,
    this.bootTimeout = defaultBootTimeout,
    this.themeMode,
    this.title = 'Mini Client',
    this.probe,
    this.routerRef,
    this.appBuilder,
    this.bootMonitoring,
    this.abandonBoot = abandonDIContainerInitialization,
    super.key,
  });

  /// Root DI initialisation, run by the [BootBloc].
  final BootTask boot;
  final McRouterFactory router;
  final PendingLinks links;
  final Duration bootTimeout;

  /// The user's theme choice. Defaults to the system setting.
  final McThemeModeController? themeMode;
  final String title;

  /// Counts route builds and redirects (tests only).
  final McRouteProbe? probe;

  /// Told about the router once it exists, for navigator implementations.
  final RouterRef? routerRef;

  /// Wraps the routed pages (the media scope). The boot page never sees it.
  final TransitionBuilder? appBuilder;

  /// Where the [BootBloc] reports transitions and boot failures. Root
  /// `Monitoring` doesn't exist until boot succeeds, so this defaults to a
  /// console-only instance.
  final Monitoring? bootMonitoring;

  /// Gives up a boot that timed out, before Retry starts a fresh one.
  final void Function() abandonBoot;

  @override
  State<McApp> createState() => _McAppState();
}

class _McAppState extends State<McApp> {
  late final BootBloc _boot = BootBloc(
    task: widget.boot,
    timeout: widget.bootTimeout,
    abandon: widget.abandonBoot,
    monitoring: widget.bootMonitoring ?? Monitoring([ConsoleSink()]),
  );
  StreamSubscription<BootState>? _bootStates;
  late final McThemeModeController _themeMode =
      widget.themeMode ?? McThemeModeController();
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    _bootStates = _boot.stream.listen(_onBoot);
    _boot.add(const BootStarted());
  }

  void _onBoot(BootState state) {
    if (state is BootReady && _router == null && mounted) {
      widget.probe?.markReady();
      final router = widget.router(widget.links.take());
      widget.routerRef?.attach(router);
      setState(() => _router = router);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // MaterialApp.router has built and go_router observes links now.
        final late = widget.links.drain();
        widget.links.detach();
        if (late != null && mounted) {
          router.go(late);
        }
      });
    }
  }

  @override
  void dispose() {
    unawaited(_bootStates?.cancel());
    unawaited(_boot.close());
    widget.routerRef?.detach();
    _router?.dispose();
    if (widget.themeMode == null) {
      _themeMode.dispose();
    }
    super.dispose();
  }

  Route<void> _bootRoute() => MaterialPageRoute<void>(
    settings: const RouteSettings(name: '/'),
    builder: (_) => StreamBuilder<BootState>(
      stream: _boot.stream,
      initialData: _boot.state,
      builder: (_, snapshot) => BootPage(
        state: snapshot.data ?? _boot.state,
        onRetry: () => _boot.add(const BootRetried()),
        title: widget.title,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final app = ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeMode,
      builder: (context, mode, _) {
        final router = _router;
        if (router == null) {
          return MaterialApp(
            key: const ValueKey('mc.boot'),
            title: widget.title,
            theme: McTheme.light,
            darkTheme: McTheme.dark,
            highContrastTheme: McTheme.highContrast,
            highContrastDarkTheme: McTheme.highContrastDarkTheme,
            themeMode: mode,
            // The platform's initial route (a cold-start link) is held by
            // PendingLinks; the boot navigator only ever shows BootPage.
            onGenerateInitialRoutes: (_) => [_bootRoute()],
            onGenerateRoute: (_) => _bootRoute(),
          );
        }
        return MaterialApp.router(
          key: const ValueKey('mc.router'),
          title: widget.title,
          theme: McTheme.light,
          darkTheme: McTheme.dark,
          highContrastTheme: McTheme.highContrast,
          highContrastDarkTheme: McTheme.highContrastDarkTheme,
          themeMode: mode,
          routerConfig: router,
          builder: widget.appBuilder,
        );
      },
    );
    final probe = widget.probe;
    return probe == null ? app : McRouteProbeScope(probe: probe, child: app);
  }
}
