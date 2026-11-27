import 'package:dio/dio.dart';
import 'package:mc_fixtures_platform/mc_fixtures_platform.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:test/test.dart';

import 'support.dart';

MockBackend _set(String set) =>
    MockBackend(domains: [platformFixtureSets[set]!()]);

MockBackend _scenario(String name) =>
    MockBackend(domains: [const PlatformMockDomain()])..useScenario(name);

Future<Response<String>> _raw(MockBackend backend, {String? user}) =>
    plainDio(backend).get<String>(
      '/v1/flags',
      options: Options(headers: user == null ? null : bearer(user)),
    );

void main() {
  test('T-0052-AC4 the fixture sets are default, empty, flags_malformed, '
      'server_error', () {
    expect(platformFixtureSets.keys, [
      'platform.default',
      'platform.empty',
      'platform.flags_malformed',
      'platform.server_error',
    ]);
    expect(
      platformFixtureSets['platform.default']!(),
      isA<PlatformMockDomain>(),
    );
    expect(
      platformFixtureSets['platform.empty']!(),
      isA<EmptyPlatformDomain>(),
    );
    expect(
      platformFixtureSets['platform.flags_malformed']!(),
      isA<MalformedFlagsPlatformDomain>(),
    );
    expect(
      platformFixtureSets['platform.server_error']!(),
      isA<FailingPlatformDomain>(),
    );
    expect(const PlatformMockDomain().scenarios.keys, [
      'platform.empty',
      'platform.flags_malformed',
      'platform.server_error',
    ]);
  });

  test(
    'T-0052-AC4 platform.default serves targeting and experiments',
    () async {
      final dio = jsonDio(_set('platform.default'));
      final anonymous = (await getFlags(dio)).data!;
      expect(anonymous['experiments']! as List, hasLength(2));
      final targeted = (await getFlags(dio, headers: bearer(reader))).data!;
      expect(targeted['flags'], isNot(anonymous['flags']));
    },
  );

  test('T-0052-AC4 platform.empty has no flags and no experiments, whoever '
      'asks', () async {
    final dio = jsonDio(_set('platform.empty'));
    for (final headers in [null, bearer(reader)]) {
      final response = await getFlags(dio, headers: headers);
      expect(response.statusCode, 200);
      expect(response.data, {
        'flags': <String, Object?>{},
        'experiments': <Object?>[],
      });
    }
    expect(const EmptyPlatformDomain().scenarios, isEmpty);
  });

  test('T-0052-AC4 platform.server_error answers 500 injected_failure, '
      'whatever the auth', () async {
    final dio = jsonDio(_set('platform.server_error'));
    for (final headers in [null, bearer(reader)]) {
      final response = await getFlags(dio, headers: headers);
      expect(response.statusCode, 500);
      expect(
        response.data!['error'],
        containsPair('code', 'injected_failure'),
      );
    }
    expect(const FailingPlatformDomain().scenarios, isEmpty);
  });

  test('T-0052-AC4 platform.flags_malformed serves wrong-typed values to '
      'everyone', () async {
    final dio = jsonDio(_set('platform.flags_malformed'));
    final anonymous = (await getFlags(dio)).data!;
    final targeted = (await getFlags(dio, headers: bearer(reader))).data!;
    expect(targeted, anonymous);
    expect((anonymous['flags']! as Map)['catalogue.page_size'], 'twenty');
    expect(const MalformedFlagsPlatformDomain().scenarios, isEmpty);
  });

  for (final name in [
    'platform.empty',
    'platform.flags_malformed',
    'platform.server_error',
  ]) {
    test('T-0052-AC4 the $name set and scenario answer the same body, status '
        'and content type for anonymous and signed-in callers', () async {
      for (final user in [null, reader, collector]) {
        final set = await _raw(_set(name), user: user);
        final scenario = await _raw(_scenario(name), user: user);
        expect(set.statusCode, scenario.statusCode, reason: '$name $user');
        expect(set.data, scenario.data, reason: '$name $user');
        expect(
          set.headers.value('content-type'),
          scenario.headers.value('content-type'),
          reason: '$name $user',
        );
      }
    });
  }

  test(
    'T-0052-AC4 negative control: the default set is not the empty set',
    () async {
      final a = await _raw(_set('platform.default'));
      final b = await _raw(_set('platform.empty'));
      expect(a.data, isNot(b.data));
    },
  );

  test(
    'T-0052-AC4 switching a scenario off restores the default body',
    () async {
      final backend = MockBackend(domains: [const PlatformMockDomain()]);
      final before = (await _raw(backend)).data;
      backend.useScenario('platform.server_error');
      expect((await _raw(backend)).statusCode, 500);
      backend.useScenario('platform.flags_malformed');
      expect((await _raw(backend)).data, isNot(before));
      backend.useScenario(null);
      expect((await _raw(backend)).data, before);
    },
  );
}
