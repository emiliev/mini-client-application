import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:retrofit_api/retrofit_api.dart';
import 'package:test/test.dart';

/// Answers every request from [_routes] and records what it was asked.
class _CannedAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  static final _routes = <String, Object?>{
    'GET /v1/characters': {
      'code': 200,
      'status': 'Ok',
      'data': {
        'offset': 0,
        'limit': 30,
        'total': 1,
        'results': [
          {
            'id': 1009610,
            'name': 'Spider-Man',
            'thumbnail_url': 'https://example.test/s.jpg',
          },
        ],
      },
    },
    'GET /v1/characters/1009610': {
      'code': 200,
      'status': 'Ok',
      'data': {'id': 1009610, 'name': 'Spider-Man', 'description': 'Bitten.'},
    },
    'POST /v1/characters/1009610/favourite': null,
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final key = '${options.method} ${options.uri.path}';
    if (!_routes.containsKey(key)) {
      return ResponseBody.fromString('', 404);
    }
    return ResponseBody.fromString(
      jsonEncode(_routes[key]),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _CannedAdapter adapter;
  late CharactersApi api;

  setUp(() {
    adapter = _CannedAdapter();
    api = CharactersApi(
      Dio()..httpClientAdapter = adapter,
      baseUrl: 'https://api.example.test/',
    );
  });

  test('T-0027-AC1 generated client decodes ApiResponse<ApiPage<CharacterDto>> with query params', () async {
    final response = await api.getCharacters(
      offset: 0,
      limit: 30,
      team: 'avengers',
    );

    expect(response.code, 200);
    expect(response.data.total, 1);
    expect(
      response.data.results.single,
      const CharacterDto(
        id: 1009610,
        name: 'Spider-Man',
        thumbnailUrl: 'https://example.test/s.jpg',
      ),
    );
    expect(adapter.requests.single.uri.queryParameters, {
      'offset': '0',
      'limit': '30',
      'team': 'avengers',
    });
  });

  test('T-0027-AC1 generated client fills path params and sends a freezed @Body as JSON', () async {
    final one = await api.getCharacter(1009610);
    expect(one.data.description, 'Bitten.');

    await api.favourite(1009610, one.data);
    final sent = adapter.requests.last;
    expect(sent.method, 'POST');
    expect(sent.uri.path, '/v1/characters/1009610/favourite');
    expect((sent.data as Map<String, dynamic>)['name'], 'Spider-Man');
  });

  test('T-0027-AC1 hand-written extension over the generated client', () async {
    final page = await api.firstPage(team: 'x-men');
    expect(page.data.results, hasLength(1));
    expect(adapter.requests.single.uri.queryParameters['team'], 'x-men');
  });
}
