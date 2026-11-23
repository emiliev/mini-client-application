import 'package:flutter/material.dart';

import 'package:hello/src/routes.dart';

void main() => runApp(HelloApp());

class HelloApp extends StatelessWidget {
  HelloApp({super.key});

  final _router = buildRouter();

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'mini-client hello',
    routerConfig: _router,
  );
}
