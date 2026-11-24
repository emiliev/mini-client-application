#!/bin/bash
# Minimal reproduction for U-D-retrofit (rules patch 0001, T-0027).
#
# Writes a self-contained Bazel workspace (an `e2e/*`-style consumer of
# rules_dart) into WORKDIR, builds an `@RestApi` file with the patched
# `@rules_dart//dart/ext/retrofit:shim`, runs a dart_test against the generated
# client, and with --compare also runs build_runner on the same sources and
# `cmp`s every generated file.
#
#   repro.sh [--compare] <rules_dart checkout with the patch applied> [WORKDIR]
#
# Needs: bazelisk or bazel (BAZEL, default `bazel`), and a Dart 3.13 SDK for
# `pub get` and build_runner (DART, default `dart`). Nothing is installed.
# Exit: 0 tests pass (and, with --compare, every file is equal), 1 otherwise.
set -euo pipefail

compare=0
if [[ "${1:-}" == "--compare" ]]; then compare=1; shift; fi
RULES="$(cd "${1:?usage: repro.sh [--compare] <rules_dart checkout> [WORKDIR]}" && pwd)"
WORK="${2:-$(mktemp -d)/retrofit_repro}"
BAZEL="${BAZEL:-bazel}"
DART="${DART:-dart}"
[[ -f "$RULES/dart/ext/retrofit/defs.bzl" ]] || { echo "no dart/ext/retrofit in $RULES: apply the patch first" >&2; exit 1; }
mkdir -p "$WORK/lib/src" "$WORK/test"
cd "$WORK"
echo "== workspace: $WORK"

echo "9.3.0" > .bazelversion
cat > MODULE.bazel <<EOF
module(name = "retrofit_repro")

bazel_dep(name = "ai_rules_dart", version = "0.0.0", repo_name = "rules_dart")
local_path_override(
    module_name = "ai_rules_dart",
    path = "$RULES",
)

dart = use_extension("@rules_dart//dart:extensions.bzl", "dart")
dart.toolchain(dart_version = "3.13.5")
use_repo(dart, "dart_toolchains")

register_toolchains("@dart_toolchains//:all")

pub = use_extension("@rules_dart//dart/pub:extensions.bzl", "pub")
pub.from_lock(
    name = "pub_deps",
    lock = "//:pubspec.lock",
    on_version_conflict = "upgrade",
)
use_repo(pub, "pub_deps")
EOF

cat > pubspec.yaml <<'EOF'
name: retrofit_repro
publish_to: none
environment:
  sdk: ^3.13.0
dependencies:
  dio: 5.11.1
  json_annotation: 4.12.0
  retrofit: 4.10.0
dev_dependencies:
  test: ^1.25.0
EOF

cat > lib/src/envelope.dart <<'EOF'
import 'package:json_annotation/json_annotation.dart';

part 'envelope.g.dart';

/// A generic response envelope, decoded through `genericArgumentFactories`.
@JsonSerializable(genericArgumentFactories: true)
class Envelope<T> {
  const Envelope({required this.code, required this.data});

  factory Envelope.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) => _$EnvelopeFromJson(json, fromJsonT);

  final int code;
  final T data;

  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) =>
      _$EnvelopeToJson(this, toJsonT);
}
EOF

cat > lib/src/character.dart <<'EOF'
import 'package:json_annotation/json_annotation.dart';

part 'character.g.dart';

/// A json_serializable model.
@JsonSerializable()
class Character {
  const Character({required this.id, required this.name});

  factory Character.fromJson(Map<String, dynamic> json) =>
      _$CharacterFromJson(json);

  final int id;
  final String name;

  Map<String, dynamic> toJson() => _$CharacterToJson(this);
}
EOF

cat > lib/src/characters_api.dart <<'EOF'
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:retrofit_repro/src/character.dart';
import 'package:retrofit_repro/src/envelope.dart';

part 'characters_api.g.dart';

/// A retrofit client over dio.
@RestApi()
abstract class CharactersApi {
  factory CharactersApi(Dio dio, {String? baseUrl}) = _CharactersApi;

  @GET('v1/characters')
  Future<Envelope<List<Character>>> list({@Query('limit') int limit = 30});

  @GET('v1/characters/{id}')
  Future<Envelope<Character>> one(@Path('id') int id);

  @POST('v1/characters')
  Future<void> create(@Body() Character character);
}
EOF

cat > test/characters_api_test.dart <<'EOF'
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:retrofit_repro/src/character.dart';
import 'package:retrofit_repro/src/characters_api.dart';
import 'package:test/test.dart';

class _Canned implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final Object? body = switch (options.uri.path) {
      '/v1/characters' when options.method == 'GET' => {
        'code': 200,
        'data': [
          {'id': 1, 'name': 'Spider-Man'},
        ],
      },
      '/v1/characters/1' => {
        'code': 200,
        'data': {'id': 1, 'name': 'Spider-Man'},
      },
      _ => null,
    };
    return ResponseBody.fromString(
      jsonEncode(body),
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
  test('generated client decodes generic envelopes and sends bodies', () async {
    final adapter = _Canned();
    final api = CharactersApi(
      Dio()..httpClientAdapter = adapter,
      baseUrl: 'https://api.example.test/',
    );
    expect((await api.list(limit: 5)).data.single.name, 'Spider-Man');
    expect(adapter.requests.last.uri.queryParameters, {'limit': '5'});
    expect((await api.one(1)).data.id, 1);
    await api.create(const Character(id: 2, name: 'Storm'));
    expect((adapter.requests.last.data as Map<String, dynamic>)['name'], 'Storm');
  });
}
EOF

cat > BUILD.bazel <<'EOF'
load("@rules_dart//dart:defs.bzl", "dart_codegen", "dart_library", "dart_test")
load("@rules_dart//dart/ext/json_serializable:defs.bzl", "json_serializable_library")
load("@rules_dart//dart/ext/retrofit:defs.bzl", "retrofit_library")

_PKG = "retrofit_repro"

_LANG = "3.13"

json_serializable_library(
    name = "models",
    srcs = [
        "lib/src/character.dart",
        "lib/src/envelope.dart",
    ],
    language_version = _LANG,
    package_name = _PKG,
)

# The macro path: one retrofit shard plus its combine.
retrofit_library(
    name = "api",
    srcs = ["lib/src/characters_api.dart"],
    language_version = _LANG,
    package_name = _PKG,
    deps = [
        ":models",
        "@pub_deps//:dio",
    ],
)

dart_test(
    name = "characters_api_test",
    size = "small",
    language_version = _LANG,
    main = "test/characters_api_test.dart",
    package_name = _PKG,
    deps = [
        ":api",
        ":models",
        "@pub_deps//:dio",
        "@pub_deps//:test",
    ],
)
EOF

echo "== pub get (writes pubspec.lock for pub.from_lock)"
$DART pub get > /dev/null

echo "== bazel test //..."
status=0
"$BAZEL" test //... || status=1
BIN="$("$BAZEL" info bazel-bin 2>/dev/null)"

if [[ $compare -eq 1 ]]; then
  echo "== build_runner reference (generator versions as in dart/ext/pubspec.lock)"
  REF="$WORK/_build_runner"
  rm -rf "$REF"
  mkdir -p "$REF"
  cp -R lib "$REF/lib"
  cp pubspec.yaml "$REF/pubspec.yaml"
  cat >> "$REF/pubspec.yaml" <<'EOF'
  analyzer: 14.5.0
  build_runner: 2.16.2
  json_serializable: 6.14.1
  retrofit_generator: 10.3.3
  # source_helper 1.4.0 clashes with json_serializable 6.14.1's own extensions
  # (`qualifiedName`, `toStringNonNullable`); the ext lock has 1.3.13.
  source_helper: 1.3.13
EOF
  (cd "$REF" && $DART pub get > /dev/null && $DART run build_runner build --delete-conflicting-outputs 2>&1 | tail -1)
  for f in character.g.dart envelope.g.dart characters_api.g.dart; do
    if cmp -s "$REF/lib/src/$f" "$BIN/lib/src/$f"; then
      echo "EQUAL   lib/src/$f"
    else
      echo "DIFFER  lib/src/$f"
      diff -u "$REF/lib/src/$f" "$BIN/lib/src/$f" || true
      status=1
    fi
  done
fi
exit $status
