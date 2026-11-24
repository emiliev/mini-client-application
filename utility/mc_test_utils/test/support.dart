import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// A tiny domain: `GET /v1/things` answers two items.
class ThingsDomain implements MockDomain {
  @override
  String get name => 'things';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) {
    router.get(
      '/v1/things/:id',
      (request, context) => MockResponse.ok({'id': context.params['id']}),
    );
    router.get(
      '/v1/things',
      (request, context) => const MockResponse.ok({
        'items': ['alpha', 'beta'],
      }),
    );
  }

  @override
  Map<String, MockScenario> get scenarios => const {
    'things_down': MockScenario(
      'things_down',
      rules: [FailureRule('GET', '/v1/things', FailureKind.http(503))],
    ),
  };
}

const String thingsSet = 'things.basic';

void registerThingsSet() => McFixtureSets.register(thingsSet, ThingsDomain.new);

/// A flow whose only page loads `GET /v1/things` through the shared Dio.
Widget thingsFlow({void Function(BuildContext context)? onBuild}) =>
    FeatureFlow<int>(
      state: 0,
      rootImports: const [RootImport<Dio>()],
      onGeneratePages: (_) => [
        McFlowPage(
          name: 'things',
          child: _ThingsPage(onBuild: onBuild),
        ),
      ],
    );

class _ThingsPage extends StatefulWidget {
  const _ThingsPage({this.onBuild});

  final void Function(BuildContext context)? onBuild;

  @override
  State<_ThingsPage> createState() => _ThingsPageState();
}

class _ThingsPageState extends State<_ThingsPage> {
  Future<String>? _load;

  @override
  Widget build(BuildContext context) {
    widget.onBuild?.call(context);
    _load ??= context
        .di<Dio>()
        .get<Map<String, dynamic>>('/v1/things')
        .then((r) => (r.data!['items'] as List<dynamic>).join(','))
        .onError<Object>((e, s) => 'error');
    return Scaffold(
      body: FutureBuilder<String>(
        future: _load,
        builder: (context, snapshot) =>
            Text(snapshot.hasData ? snapshot.data! : 'loading'),
      ),
    );
  }
}
