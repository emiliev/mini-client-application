import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:mc_fixtures_discovery/mc_fixtures_discovery.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

Future<String> get(Dio d, String p) async {
  final r = await d.get<String>(p,
      options: Options(
          responseType: ResponseType.plain, validateStatus: (_) => true));
  return '${r.statusCode} ${r.data}';
}

String brief(String raw) {
  final i = raw.indexOf(' ');
  final status = raw.substring(0, i);
  final j = jsonDecode(raw.substring(i + 1)) as Map<String, Object?>;
  if (j.containsKey('error')) return '$status ${jsonEncode(j['error'])}';
  if (j.containsKey('suggestions')) return '$status ${jsonEncode(j['suggestions'])}';
  final gs = (j['groups'] as List).cast<Map<String, Object?>>();
  return '$status q=${j['query']} ' +
      gs
          .map((g) =>
              '${g['type']}:${g['total']}[${(g['results'] as List).map((r) => (r as Map)['title']).take(4).join('|')}]')
          .join(' ');
}

Future<void> main() async {
  final b1 = MockBackend(seed: 42, domains: [const DiscoveryMockDomain()]);
  final b2 = MockBackend(seed: 42, domains: [const DiscoveryMockDomain()]);
  final paths = [
    '/v1/search?q=spi',
    '/v1/search?q=spi&limit=3',
    '/v1/search?q=ard&types=character',
    '/v1/search?q=Amber%20Chronicles%20%231&types=comic',
    '/v1/search?q=spindle',
    '/v1/search/suggestions?q=spi',
    '/v1/search?q=%20%20sp%20%20',
    '/v1/search?q=Spindle&limit=100',
  ];
  var same = true;
  for (final p in paths) {
    final a = await get(b1.createDio(), p);
    final c = await get(b2.createDio(), p);
    if (a != c) same = false;
  }
  print('AC1 identical: $same');

  final d = b1.createDio();
  for (final p in [
    '/v1/search?q=spi',
    '/v1/search?q=iro',
    '/v1/search?q=chr&limit=5',
    '/v1/search?q=a',
    '/v1/search?q=',
    '/v1/search',
    '/v1/search?q=%20a%20',
    '/v1/search?q=%CC%81%CC%81',
    '/v1/search?q=e%CC%81',
    '/v1/search?q=%C3%A9',
    '/v1/search?q=%C3%A9%C3%A9',
    '/v1/search?q=spi&types=hero',
    '/v1/search?q=spi&types=',
    '/v1/search?q=spi&types=character,',
    '/v1/search?q=spi&types=Character',
    '/v1/search?q=spi&types=comic,character&limit=1',
    '/v1/search?q=spi&limit=0',
    '/v1/search?q=spi&limit=1',
    '/v1/search?q=spi&limit=100',
    '/v1/search?q=spi&limit=101',
    '/v1/search?q=spi&limit=-1',
    '/v1/search?q=spi&limit=abc',
    '/v1/search?q=spi&limit=',
    '/v1/search?q=zzzzqq',
    '/v1/search?q=%C8%98tiin%C8%9Ba',
    '/v1/search?q=stiinta',
    '/v1/search?q=Vi%E1%BB%87t',
    '/v1/search?q=viet',
    '/v1/search/suggestions?q=a',
    '/v1/search/suggestions?q=spi',
    '/v1/nothing',
  ]) {
    print('$p\n   ${brief(await get(d, p))}');
  }
  print('foldText Știința=${foldText('Știința')} stiinta=${foldText('stiinta')} '
      'Việt=${foldText('Việt')} Ǆ=${foldText('ǅ')} ');

  // empty / server_error sets vs scenarios
  for (final name in ['empty', 'server_error']) {
    final dom = name == 'empty'
        ? const EmptyDiscoveryDomain() as MockDomain
        : const FailingDiscoveryDomain();
    final setB = MockBackend(seed: 42, domains: [dom]);
    final scB = MockBackend(seed: 42, domains: [const DiscoveryMockDomain()])..useScenario('discovery.$name');
    for (final p in ['/v1/search?q=spi', '/v1/search/suggestions?q=spi', '/v1/search?q=a', '/v1/search?q=spi&types=x']) {
      final x = await get(setB.createDio(), p); final y = await get(scB.createDio(), p); print('$name $p same=${x==y} ${brief(x)}');
    }
  }
}
