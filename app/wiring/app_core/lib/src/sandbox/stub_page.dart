import 'package:flutter/material.dart';

/// What a sandbox app shows for a route that belongs to another group
/// (plan 01 §3.4, §6.3): the sandbox hosts one wiring, not the whole app.
class SandboxStubPage extends StatelessWidget {
  const SandboxStubPage({required this.location, super.key});

  final String location;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('sandbox.stub'),
    appBar: AppBar(title: const Text('Sandbox')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Text('$location is not part of this sandbox.'),
    ),
  );
}
