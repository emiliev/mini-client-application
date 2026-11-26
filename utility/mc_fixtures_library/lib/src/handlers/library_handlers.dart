import 'dart:async';

import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_fixtures_library/src/data/reading_list.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

const String _stateKey = 'library.state';
const String _emptyStateKey = 'library.state.empty';

/// The comics the seeded lists hold, as positions in title order (so they
/// never depend on how ids are numbered).
const List<List<int>> _seedItems = [
  [0, 40, 80],
  [5, 15],
  [],
  [100, 200, 300],
];

/// The lists of every user, seeding on first use. [seed] false starts empty
/// and keeps its own state, so the `library.empty` scenario is empty even
/// after the default handlers ran.
LibraryState _state(
  MockContext context,
  ComicUniverse universe, {
  required bool seed,
}) {
  final key = seed ? _stateKey : _emptyStateKey;
  final existing = context.store[key];
  if (existing != null) {
    return existing as LibraryState;
  }
  final byUser = <String, List<ReadingList>>{
    for (final user in fixtureUsers) user.id: <ReadingList>[],
  };
  var next = 1;
  if (seed) {
    void make(
      String user,
      String name,
      String description,
      String visibility,
      int index,
      int ageDays,
    ) {
      byUser[user]!.add(
        ReadingList(
          id: 'l-${next++}',
          name: name,
          description: description,
          visibility: visibility,
          comicIds: [for (final i in _seedItems[index]) universe.byTitle[i].id],
          updatedAt: context.clock.subtract(Duration(days: ageDays)),
        ),
      );
    }

    make('u-100', 'Spider-Verse Starter', 'Where to begin.', 'public', 0, 2);
    make('u-100', 'Weekend Reads', '', 'private', 1, 10);
    make('u-100', 'Someday', 'Nothing here yet.', 'private', 2, 30);
    make('u-101', 'Collector Shortlist', 'Keepers.', 'public', 3, 5);
  }
  return context.store[key] = LibraryState(byUser, next);
}

MockResponse _unauthenticated() => MockResponse.error(
  401,
  'unauthenticated',
  'A valid bearer token is required',
);

MockResponse _notFound(String id) => MockResponse.error(
  404,
  'list_not_found',
  'No reading list "$id"',
  extra: {'id': id},
);

MockResponse _invalid(
  String code,
  String message,
  Map<String, Object?> extra,
) => MockResponse.error(400, code, message, extra: extra);

Map<String, Object?> _detail(ReadingList list, ComicUniverse universe) => {
  ...list.toSummaryJson(),
  'items': [
    for (final id in list.comicIds)
      {
        'id': id,
        'title': universe.findComic(id)!.title,
        'thumbnail': universe.findComic(id)!.cover.toJson(),
      },
  ],
};

MockResponse? _checkName(Object? raw) {
  final length = raw is String ? raw.trim().runes.length : -1;
  if (length < nameMinLength || length > nameMaxLength) {
    return _invalid(
      'invalid_name',
      'name must be $nameMinLength to $nameMaxLength characters after '
          'trimming',
      {'parameter': 'name'},
    );
  }
  return null;
}

MockResponse? _checkDescription(Object? raw) {
  if (raw != null &&
      (raw is! String || raw.runes.length > descriptionMaxLength)) {
    return _invalid(
      'invalid_description',
      'description must be a string of at most $descriptionMaxLength '
          'characters',
      {'parameter': 'description'},
    );
  }
  return null;
}

MockResponse? _checkVisibility(Object? raw) {
  if (!visibilities.contains(raw)) {
    return _invalid(
      'invalid_visibility',
      'visibility must be one of ${visibilities.join(', ')}',
      {'parameter': 'visibility'},
    );
  }
  return null;
}

/// Checks `comicIds` in the order: shape, count, duplicates, unknown ids.
MockResponse? _checkComicIds(Object? raw, ComicUniverse universe) {
  if (raw is! List || raw.any((e) => e is! int)) {
    return _invalid('invalid_body', 'comicIds must be a list of integers', {
      'parameter': 'comicIds',
    });
  }
  final ids = raw.cast<int>();
  if (ids.length > maxComicsPerList) {
    return _invalid(
      'too_many_comics',
      'a list holds at most $maxComicsPerList comics',
      {'parameter': 'comicIds', 'maxItems': maxComicsPerList},
    );
  }
  final seen = <int>{};
  for (final id in ids) {
    if (!seen.add(id)) {
      return _invalid('duplicate_comic', 'comic $id appears more than once', {
        'parameter': 'comicIds',
        'comicId': id,
      });
    }
  }
  for (final id in ids) {
    if (universe.findComic(id) == null) {
      return _invalid('unknown_comic', 'comic $id does not exist', {
        'parameter': 'comicIds',
        'comicId': id,
      });
    }
  }
  return null;
}

final MockResponse _notAnObject = MockResponse.error(
  400,
  'invalid_body',
  'Expected a JSON object',
);

ReadingList? _find(LibraryState state, String user, String id) {
  for (final list in state.listsByUser[user]!) {
    if (list.id == id) {
      return list;
    }
  }
  return null;
}

/// The `updatedAt` of a write: the fixed clock plus one second per write, so
/// the order of edits shows in the list order.
DateTime _touch(LibraryState state, MockContext context) =>
    context.clock.add(Duration(seconds: ++state.ticks));

/// Wraps [body] with the bearer check; [body] gets the signed-in user.
MockHandler _authed(
  FutureOr<MockResponse> Function(
    FixtureUser user,
    MockRequest request,
    MockContext context,
  )
  body,
) => (request, context) {
  final user = userForAuthorization(request.headers['authorization']);
  return user == null ? _unauthenticated() : body(user, request, context);
};

int _byUpdated(ReadingList a, ReadingList b) {
  final byTime = b.updatedAt.compareTo(a.updatedAt);
  return byTime != 0 ? byTime : a.id.compareTo(b.id);
}

/// `GET /v1/me/lists`: the user's lists, most recently updated first.
MockHandler listLists(ComicUniverse universe, {required bool seed}) =>
    _authed((user, request, context) {
      final lists = [
        ..._state(context, universe, seed: seed).listsByUser[user.id]!,
      ]..sort(_byUpdated);
      return MockResponse.ok({
        'lists': [for (final l in lists) l.toSummaryJson()],
      });
    });

/// `GET /v1/me/lists/:id`.
MockHandler getList(ComicUniverse universe, {required bool seed}) =>
    _authed((user, request, context) {
      final id = context.params['id']!;
      final list = _find(_state(context, universe, seed: seed), user.id, id);
      return list == null
          ? _notFound(id)
          : MockResponse.ok(_detail(list, universe));
    });

/// `POST /v1/me/lists` with `{name, description?, visibility, comicIds}`.
MockHandler createList(ComicUniverse universe, {required bool seed}) =>
    _authed((user, request, context) {
      final body = request.body;
      if (body is! Map) {
        return _notAnObject;
      }
      final error =
          _checkName(body['name']) ??
          _checkDescription(body['description']) ??
          _checkVisibility(body['visibility']) ??
          _checkComicIds(body['comicIds'], universe);
      if (error != null) {
        return error;
      }
      final state = _state(context, universe, seed: seed);
      final list = ReadingList(
        id: 'l-${state.nextNumber++}',
        name: (body['name'] as String).trim(),
        description: body['description'] as String? ?? '',
        visibility: body['visibility'] as String,
        comicIds: [...(body['comicIds'] as List).cast<int>()],
        updatedAt: _touch(state, context),
      );
      state.listsByUser[user.id]!.add(list);
      return MockResponse(201, _detail(list, universe));
    });

/// `PUT /v1/me/lists/:id` with `{name, description?, visibility}`. The items
/// are left as they are; an absent description clears it.
MockHandler updateList(ComicUniverse universe, {required bool seed}) =>
    _authed((user, request, context) {
      final id = context.params['id']!;
      final state = _state(context, universe, seed: seed);
      final list = _find(state, user.id, id);
      if (list == null) {
        return _notFound(id);
      }
      final body = request.body;
      if (body is! Map) {
        return _notAnObject;
      }
      final error =
          _checkName(body['name']) ??
          _checkDescription(body['description']) ??
          _checkVisibility(body['visibility']);
      if (error != null) {
        return error;
      }
      list
        ..name = (body['name'] as String).trim()
        ..description = body['description'] as String? ?? ''
        ..visibility = body['visibility'] as String
        ..updatedAt = _touch(state, context);
      return MockResponse.ok(_detail(list, universe));
    });

/// `PUT /v1/me/lists/:id/items` with `{comicIds}`: the new order, exactly.
MockHandler replaceItems(ComicUniverse universe, {required bool seed}) =>
    _authed((user, request, context) {
      final id = context.params['id']!;
      final state = _state(context, universe, seed: seed);
      final list = _find(state, user.id, id);
      if (list == null) {
        return _notFound(id);
      }
      final body = request.body;
      if (body is! Map) {
        return _notAnObject;
      }
      final error = _checkComicIds(body['comicIds'], universe);
      if (error != null) {
        return error;
      }
      list
        ..comicIds = [...(body['comicIds'] as List).cast<int>()]
        ..updatedAt = _touch(state, context);
      return MockResponse.ok(_detail(list, universe));
    });

/// `DELETE /v1/me/lists/:id`: `204`, or `404` for an unknown or foreign id.
MockHandler deleteList(ComicUniverse universe, {required bool seed}) =>
    _authed((user, request, context) {
      final id = context.params['id']!;
      final state = _state(context, universe, seed: seed);
      final list = _find(state, user.id, id);
      if (list == null) {
        return _notFound(id);
      }
      state.listsByUser[user.id]!.remove(list);
      return const MockResponse(204);
    });

/// The `server_error` set: the exact body the `library.server_error`
/// scenario's `FailureRule` produces, so both fail the same way.
MockResponse serverError(MockRequest request, MockContext context) =>
    MockResponse.error(
      500,
      'injected_failure',
      'Injected HTTP 500 for ${request.routeKey}',
    );
