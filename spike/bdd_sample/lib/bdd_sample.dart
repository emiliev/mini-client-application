/// A one-page flow for the T-0029 BDD spike: it loads `GET /v1/greeting`
/// through the shared Dio and shows the greeting and a button.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';

/// The greeting flow, entered the way a feature is: through its flow.
Widget greetingFlow() => FeatureFlow<int>(
  state: 0,
  rootImports: const [RootImport<Dio>()],
  onGeneratePages: (_) => [
    const McFlowPage(name: 'greeting', child: _GreetingPage()),
  ],
);

class _GreetingPage extends StatefulWidget {
  const _GreetingPage();

  @override
  State<_GreetingPage> createState() => _GreetingPageState();
}

class _GreetingPageState extends State<_GreetingPage> {
  Future<String>? _load;
  bool _goodbye = false;

  @override
  Widget build(BuildContext context) {
    _load ??= context
        .di<Dio>()
        .get<Map<String, dynamic>>('/v1/greeting')
        .then((r) => r.data!['text'] as String)
        .onError<Object>((e, s) => 'Something went wrong');
    return Scaffold(
      body: FutureBuilder<String>(
        future: _load,
        builder: (context, snapshot) => Column(
          children: [
            Text(_goodbye ? 'Goodbye' : (snapshot.data ?? 'Loading')),
            TextButton(
              onPressed: () => setState(() => _goodbye = true),
              child: const Text('Say goodbye'),
            ),
          ],
        ),
      ),
    );
  }
}
