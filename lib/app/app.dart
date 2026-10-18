import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/settings.dart';
import 'router.dart';
import 'theme.dart';

/// Created once per app process; [startOnScan] is read at first build.
final appRouterProvider = Provider<GoRouter>((ref) {
  final startOnScan = ref.read(appSettingsProvider).startOnScan;
  return buildAppRouter(startOnScan: startOnScan);
});

class SoGiaApp extends ConsumerWidget {
  const SoGiaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(uiPrefsProvider);
    final settings = ref.watch(appSettingsProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Sổ giá',
      theme: buildAppTheme(
        largeText: settings.largeText,
        highContrast: settings.highContrast,
      ),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(settings.largeText ? 1.15 : 1.0),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
