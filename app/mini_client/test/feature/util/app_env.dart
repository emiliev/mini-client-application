import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Called once per suite by the BDD aggregator (`mc_bdd_tests(setup = ...)`).
void bddSetUpAll() {
  charactersFixtureSets.forEach(McFixtureSets.register);
}
