import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class SoGiaApp extends StatelessWidget {
  const SoGiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Sổ giá',
      theme: buildAppTheme(),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
