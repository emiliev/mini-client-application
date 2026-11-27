import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_fixtures_platform/mc_fixtures_platform.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('T-0052-AC4 seed 42 answers byte-identical bodies on every call and '
      'on a fresh backend', () async {
    final first = platformBackend();
    final a = await plainDio(first).get<String>('/v1/flags');
    final b = await plainDio(first).get<String>('/v1/flags');
    final c = await plainDio(platformBackend()).get<String>('/v1/flags');
    expect(a.statusCode, 200);
    expect(a.data, isNotEmpty);
    expect(b.data, a.data);
    expect(c.data, a.data);
    first.reset();
    expect((await plainDio(first).get<String>('/v1/flags')).data, a.data);
  });

  test('T-0052-AC4 the flags do not depend on the seed (documented)', () async {
    final a = await plainDio(platformBackend()).get<String>('/v1/flags');
    final b = await plainDio(
      platformBackend(seed: 7),
    ).get<String>('/v1/flags');
    expect(b.data, a.data);
  });

  test('T-0052-AC4 the body has flags and experiments, with the documented '
      'shape', () async {
    final body = (await getFlags(jsonDio(platformBackend()))).data!;
    expect(body.keys, unorderedEquals(['flags', 'experiments']));
    final flags = body['flags']! as Map<String, Object?>;
    expect(flags, {
      'catalogue.page_size': 20,
      'dev.diagnostics': false,
      'search.layout': 'grid',
      'settings.accent': 'red',
      'store.promo_banner': false,
    });
    final experiments = (body['experiments']! as List)
        .cast<Map<String, Object?>>();
    expect(
      [for (final e in experiments) e['key']],
      [
        'store_home_layout',
        'trivia_hint',
      ],
    );
    final layout = (experiments.first['variants']! as List)
        .cast<Map<String, Object?>>();
    expect(
      [for (final v in layout) (v['name'], v['weight'])],
      [('control', 5000), ('compact', 3000), ('rich', 2000)],
    );
    final hint = (experiments.last['variants']! as List)
        .cast<Map<String, Object?>>();
    expect(
      [for (final v in hint) (v['name'], v['weight'])],
      [('control', 10000), ('hint', 0)],
    );
  });

  test(
    'T-0052-AC4 a seeded user is targeted differently from anonymous',
    () async {
      final dio = jsonDio(platformBackend());
      final anonymous = (await getFlags(dio)).data!['flags']! as Map;
      final u100 =
          (await getFlags(dio, headers: bearer(reader))).data!['flags']! as Map;
      final u101 =
          (await getFlags(dio, headers: bearer(collector))).data!['flags']!
              as Map;
      expect(u100['store.promo_banner'], isTrue);
      expect(anonymous['store.promo_banner'], isFalse);
      expect(u100['search.layout'], 'list');
      expect(anonymous['search.layout'], 'grid');
      expect(u101['catalogue.page_size'], 40);
      expect(anonymous['catalogue.page_size'], 20);
      // Everything not targeted stays the anonymous value.
      expect(u100['settings.accent'], anonymous['settings.accent']);
      expect(u100['catalogue.page_size'], anonymous['catalogue.page_size']);
      expect(u101['store.promo_banner'], anonymous['store.promo_banner']);
      expect(flagsForUser('u-100'), u100);
      expect(flagsForUser('u-101'), u101);
      expect(flagsForUser(null), anonymous);
      expect(flagsForUser('u-999'), anonymous);
    },
  );

  test('T-0052-AC4 a bad bearer is anonymous and never a 401 (auth is '
      'optional)', () async {
    final dio = jsonDio(platformBackend());
    final anonymous = (await getFlags(dio)).data;
    for (final header in [
      'Bearer ${expiredAccessToken(reader)}',
      'Bearer garbage',
      'Bearer ${mintRefreshToken(reader, 1)}',
      'Basic ${mintAccessToken(reader, 1)}',
      'Bearer ${mintAccessToken('u-999', 1)}',
    ]) {
      final response = await getFlags(dio, headers: {'Authorization': header});
      expect(response.statusCode, 200, reason: header);
      expect(response.data, anonymous, reason: header);
    }
  });

  test('T-0052-AC4 the malformed body has wrong-typed values and the rest '
      'valid', () async {
    final body = (await getFlags(
      jsonDio(platformBackend(domain: const MalformedFlagsPlatformDomain())),
    )).data!;
    final flags = body['flags']! as Map<String, Object?>;
    expect(flags['catalogue.page_size'], 'twenty');
    expect(flags['store.promo_banner'], 1);
    expect(flags['search.layout'], 'carousel');
    expect(flags['settings.accent'], 'red');
    expect(flags['dev.diagnostics'], false);
    final layout =
        ((body['experiments']! as List).first
                as Map<String, Object?>)['variants']!
            as List;
    expect((layout[1]! as Map)['weight'], 'heavy');
    expect(flagsBodyMalformed(), body);
    expect(flagsBodyEmpty()['flags'], isEmpty);
    expect(flagsBodyDefault(null)['experiments'], isNotEmpty);
  });

  test('T-0052-AC4 only GET /v1/flags exists', () {
    final backend = platformBackend();
    expect(
      [for (final r in backend.router.routes) r.key],
      [
        'GET /v1/flags',
      ],
    );
    expect(PlatformMockDomain.routeManifest, platformRouteManifest);
  });
}
