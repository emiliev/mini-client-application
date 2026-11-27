import 'package:flutter/widgets.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_fixtures_commerce/mc_fixtures_commerce.dart';
import 'package:mc_fixtures_discovery/mc_fixtures_discovery.dart';
import 'package:mc_fixtures_editorial/mc_fixtures_editorial.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_fixtures_library/mc_fixtures_library.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_fixtures_platform/mc_fixtures_platform.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// The mocked backend's domains in the apps (D5). Fixtures are allowed only
/// here, in app wiring, and in backend code, never in a feature or the DS.
/// Each feature's task adds its domain.
const List<MockDomain> appMockDomains = [
  CharactersMockDomain(),
  ComicsMockDomain(),
  CommerceMockDomain(),
  DiscoveryMockDomain(),
  IdentityMockDomain(),
  LibraryMockDomain(),
  PlatformMockDomain(),
  TriviaMockDomain(),
];

/// The app root's media scope: `McImage` resolves `mock-asset://` art from the
/// bundled placeholders (D4d). Pass to `McApp.appBuilder`.
Widget mediaScopeBuilder(BuildContext context, Widget? child) => McMediaScope(
  resolver: const BundledImageResolver(),
  child: child ?? const SizedBox.shrink(),
);
