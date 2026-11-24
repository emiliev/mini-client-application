# F-0025: under the Bazel shim, a bare `@freezed` model silently loses its JSON

- **Date:** 2026-11-24
- **Author:** crew: Engineer (T-0027)
- **Type:** Library behaviour (freezed 4.0.2 under rules_dart's builder shim); upstream candidate
- **Related:** T-0027-AC1, plan 03 §3.4 and §4.1, R16, F-0011, [evidence](../evidence/T-0027/engineer/f0025-bare-freezed-diff.log)

## Summary
freezed 4.0.2 decides whether to emit `toJson`, `@JsonSerializable()` and the `fromJson` redirect from `Library.hasJson`. That check walks the library's imports and accepts `JsonSerializable` only when its source's `fullName` **starts with `/json_annotation/`** (`lib/src/tools/recursive_import_locator.dart:5`, `isFromPackage`). build_runner gives sources that asset-style path. rules_dart's shim gives real file or summary paths (for example `…/pub_deps__json_annotation/…`), so the check fails. A model written the usual way (`@freezed` with `factory X.fromJson(...) => _$XFromJson(json)`) then gets:
- a `.freezed.dart` without `toJson`, `@JsonSerializable()` or `_X.fromJson`;
- an **empty** `.json_serializable.g.part`, so the `.g.dart` holds only its header.

Nothing fails at codegen time. The first error is at kernel compile: `Method not found: '_$CharacterDtoFromJson'` and `The method 'toJson' isn't defined`. rules_dart's own exemplar (`e2e/ext_exemplar/cascade_two_stage/lib/event.dart`) records the same issue and uses the workaround below.

**Workaround:** write the flags out, `@Freezed(fromJson: true, toJson: true)`. With that, the Bazel freezed and json outputs are byte-identical to build_runner's on the same source (T-0027-AC1).

## Evidence
- `spike/retrofit_api/lib/src/character_dto.dart` with a bare `@freezed`: `spike_reference.sh spike/retrofit_api` reports `DIFFER` for `character_dto.freezed.dart` and `character_dto.g.dart`; build_runner's output has the JSON members and Bazel's doesn't ([diff](../evidence/T-0027/engineer/f0025-bare-freezed-diff.log)). `characters_api.g.dart` stays `EQUAL`, because retrofit only calls `toJson` and `fromJson` by name.
- With `@Freezed(fromJson: true, toJson: true)`: all five files `EQUAL` ([T-0027-AC1](../evidence/T-0027/engineer/T-0027-AC1.md)).

## Implications / actions
- **TL decision (2026-11-24): adopted.** Every freezed model with JSON uses `@Freezed(fromJson: true, toJson: true)`. The TL records the deviation in ADR-0007 and files the shim fix as an upstream candidate at merge.
- **Templates and buildgen (P1-24, P2):** every freezed model with JSON must use `@Freezed(fromJson: true, toJson: true)`, never a bare `@freezed`. A lint or `buildgen --check` rule should flag a `fromJson` factory under a bare `@freezed`. This is a Tide deviation, so it must be recorded (Tide writes `@freezed`).
- **Upstream candidates (TL decides):** (a) rules_dart: the shim could present sources with build_runner's `/<package>/lib/…` `fullName`, in line with its stated bug-compatibility with `build_resolvers`; (b) freezed: decide by library URI (`package:json_annotation/…`), not by path.
- Until then, a freezed + json model that compiles under Bazel proves the flags are set, because without them the build fails at kernel compile.
