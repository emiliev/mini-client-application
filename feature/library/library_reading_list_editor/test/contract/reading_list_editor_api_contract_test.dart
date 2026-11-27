// Contract tests are the one place a feature test reaches `src/` (R7): the
// wire shapes and the repository's mapping, against what the fixture domains
// actually serve (`mc_fixtures_library`, `mc_fixtures_comics` CONTRACT.md).
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_reading_list_editor/src/domain/api/reading_list_editor_api.dart';
import 'package:library_reading_list_editor/src/domain/model/comic_id.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list_dto.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list_id.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list_mapper.dart';
import 'package:library_reading_list_editor/src/domain/repository/reading_list_editor_repository.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_fixtures_library/mc_fixtures_library.dart';
import 'package:mc_media/mc_media.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_prelude/mc_prelude.dart';

/// A fresh default backend per test, with u-100's bearer on every request,
/// as the app's auth interceptor puts it there.
({Dio dio, ReadingListEditorRepository repository}) _backend() {
  final dio =
      MockBackend(
          domains: const [
            LibraryMockDomain(),
            ComicsMockDomain(),
            IdentityMockDomain(),
          ],
        ).createDio()
        ..options.headers['Authorization'] =
            'Bearer ${mintAccessToken('u-100', 1)}';
  return (
    dio: dio,
    repository: ReadingListEditorRepository(ReadingListEditorApi(dio)),
  );
}

const _draft = ReadingListDraft(
  name: 'Amber reads',
  description: 'Where Amber begins.',
  visibility: ReadingListVisibility.public,
  comicIds: [ComicId(500060), ComicId(500062)],
);

T _success<T, F>(Result<T, F> result) =>
    result.fold((v) => v, (f) => fail('expected a success, got $f'));

F _failure<T, F>(Result<T, F> result) =>
    result.fold((v) => fail('expected a failure, got $v'), (f) => f);

void main() {
  group('T-0048-AC7 the DTOs against the served JSON', () {
    test('T-0048-AC7 GET /v1/me/lists/:id round-trips byte for byte', () async {
      final b = _backend();
      final response = await b.dio.get<String>(
        '/v1/me/lists/l-1',
        options: Options(responseType: ResponseType.plain),
      );
      final json = jsonDecode(response.data!) as Map<String, dynamic>;
      final dto = ReadingListDto.fromJson(json);

      expect(canonicalJson(dto.toJson()), canonicalJson(json));
      expect(dto.id, 'l-1');
      expect(dto.name, 'Spider-Verse Starter');
      expect(dto.visibility, 'public');
      expect(dto.itemCount, 3);
      expect([for (final i in dto.items) i.id], [500060, 501500, 500540]);
    });

    test(
      'T-0048-AC7 GET /v1/comics results round-trip byte for byte',
      () async {
        final b = _backend();
        final response = await b.dio.get<Map<String, dynamic>>(
          '/v1/comics',
          queryParameters: {'titleStartsWith': 'Amber Chr', 'limit': 3},
        );
        final results = response.data!['results'] as List<Object?>;
        expect(results, hasLength(3));
        for (final raw in results) {
          final json = raw! as Map<String, dynamic>;
          expect(
            canonicalJson(ComicHitDto.fromJson(json).toJson()),
            canonicalJson(json),
          );
        }
      },
    );

    test('T-0048-AC7 the write bodies have exactly the contract keys', () {
      expect(_draft.toCreateDto().toJson(), {
        'name': 'Amber reads',
        'description': 'Where Amber begins.',
        'visibility': 'public',
        'comicIds': [500060, 500062],
      });
      expect(_draft.toDetailsDto().toJson(), {
        'name': 'Amber reads',
        'description': 'Where Amber begins.',
        'visibility': 'public',
      });
      expect(_draft.toItemsDto().toJson(), {
        'comicIds': [500060, 500062],
      });
      // And back, for the round trip of every DTO.
      expect(
        CreateReadingListDto.fromJson(_draft.toCreateDto().toJson()),
        _draft.toCreateDto(),
      );
      expect(
        ReadingListDetailsDto.fromJson(_draft.toDetailsDto().toJson()),
        _draft.toDetailsDto(),
      );
      expect(
        ReadingListItemsDto.fromJson(_draft.toItemsDto().toJson()),
        _draft.toItemsDto(),
      );
    });
  });

  group('T-0048-AC3 the repository against the library domain', () {
    test('T-0048-AC3 fetchList maps the list and its items in order', () async {
      final list = _success(
        await _backend().repository.fetchList(const ReadingListId('l-1')),
      );
      expect(list.id, const ReadingListId('l-1'));
      expect(list.description, 'Where to begin.');
      expect(list.visibility, ReadingListVisibility.public);
      expect(
        [for (final c in list.comics) c.title],
        [
          'Amber Chronicles #1',
          'Amber Frontier #1',
          'Amber Legacy #1',
        ],
      );
      expect(
        list.comics.first.cover,
        const ApiImage(
          path: 'mock-asset://characters/003',
          variant: ImageVariant.portraitLarge,
        ),
      );
    });

    test(
      "T-0048-AC3 another user's list and an unknown id are not found",
      () async {
        final repository = _backend().repository;
        for (final id in ['l-4', 'l-999']) {
          expect(
            _failure(await repository.fetchList(ReadingListId(id))),
            isA<ApiNotFound>(),
            reason: id,
          );
        }
      },
    );

    test('T-0048-AC1 create answers the new list with its id', () async {
      final list = _success(
        await _backend().repository.create(_draft, epoch: 0),
      );
      expect(list.id, const ReadingListId('l-5'));
      expect([for (final c in list.comics) c.id], _draft.comicIds);
    });

    test(
      'T-0048-AC3 updateDetails and replaceItems answer the saved list',
      () async {
        final repository = _backend().repository;
        const id = ReadingListId('l-1');
        final details = _success(
          await repository.updateDetails(id, _draft, epoch: 0),
        );
        expect(details.name, 'Amber reads');
        expect(details.comics, hasLength(3), reason: 'items untouched');
        final items = _success(
          await repository.replaceItems(id, _draft, epoch: 0),
        );
        expect([for (final c in items.comics) c.id], _draft.comicIds);
        expect(items.name, 'Amber reads');
      },
    );

    test(
      'T-0048-AC1 searchComics: a prefix narrows, an empty query lists all',
      () async {
        final repository = _backend().repository;
        final narrowed = _success(await repository.searchComics('Amber Fr'));
        expect(narrowed, hasLength(comicSearchLimit));
        expect(
          narrowed.every((c) => c.title.startsWith('Amber Frontier')),
          isTrue,
        );
        final all = _success(await repository.searchComics(''));
        expect(all.first.title, 'Amber Chronicles #1');
        expect(
          _success(await repository.searchComics('zzz')),
          isEmpty,
        );
      },
    );
  });

  group('T-0048-AC2 a refused write is an ApiClientError naming the code '
      'and the field', () {
    Future<ApiClientError> reject(ReadingListDraft draft) async =>
        _failure(await _backend().repository.create(draft, epoch: 0))
            as ApiClientError;

    test('T-0048-AC2 duplicate_name: a name the user already has', () async {
      final error = await reject(_draft.copyWith(name: 'weekend reads'));
      expect(error.status, 400);
      expect(error.code, 'duplicate_name');
      expect(error.parameter, 'name');
    });

    test('T-0048-AC2 the comics: a duplicate and too many', () async {
      final duplicate = await reject(
        _draft.copyWith(comicIds: const [ComicId(500060), ComicId(500060)]),
      );
      expect(
        (duplicate.code, duplicate.parameter),
        ('duplicate_comic', 'comicIds'),
      );
      final tooMany = await reject(
        _draft.copyWith(
          comicIds: [for (var i = 0; i < 101; i++) ComicId(500000 + i)],
        ),
      );
      expect(
        (tooMany.code, tooMany.parameter),
        ('too_many_comics', 'comicIds'),
      );
    });

    test('T-0048-AC2 a renamed list that takes another list\'s name', () async {
      final error = _failure(
        await _backend().repository.updateDetails(
          const ReadingListId('l-1'),
          _draft.copyWith(name: 'Someday'),
          epoch: 0,
        ),
      ) as ApiClientError;
      expect((error.code, error.parameter), ('duplicate_name', 'name'));
    });

    test('T-0048-AC1 names and descriptions are counted as a reader sees '
        'them: 60 flags are a valid name', () async {
      final list = _success(
        await _backend().repository.create(
          _draft.copyWith(
            name: '\u{1F1E9}\u{1F1EA}' * 60,
            description: '\u{1F1E9}\u{1F1EA}' * 280,
          ),
          epoch: 0,
        ),
      );
      expect(list.id, const ReadingListId('l-5'));
    });
  });

  test('T-0050-AC2 every write of the repository is pinned to the epoch it is '
      'given, and no read is', () async {
    final b = _backend();
    final pins = <String, Object?>{};
    b.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          pins['${options.method} ${options.uri.path}'] =
              options.extra[mcSessionEpoch];
          handler.next(options);
        },
      ),
    );
    const id = ReadingListId('l-1');

    await b.repository.create(_draft, epoch: 7);
    await b.repository.updateDetails(id, _draft, epoch: 8);
    await b.repository.replaceItems(id, _draft, epoch: 9);
    await b.repository.fetchList(id);
    await b.repository.searchComics('A');

    expect(pins, {
      'POST /v1/me/lists': 7,
      'PUT /v1/me/lists/l-1': 8,
      'PUT /v1/me/lists/l-1/items': 9,
      'GET /v1/me/lists/l-1': null,
      'GET /v1/comics': null,
    });
  });

  test('T-0048-AC7 a value outside the contract is malformed', () async {
    expect(
      () => ReadingListVisibility.fromWire('friends'),
      throwsFormatException,
    );
    const dto = ReadingListDto(
      id: 'l-9',
      name: 'x',
      description: '',
      visibility: 'friends',
      itemCount: 0,
      updatedAt: '2026-01-01T00:00:00.000Z',
      items: [],
    );
    expect(() => dto.toDomain(), throwsFormatException);
  });
}
