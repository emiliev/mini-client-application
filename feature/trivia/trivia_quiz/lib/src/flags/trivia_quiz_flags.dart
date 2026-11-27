import 'package:mc_feature_flags/mc_feature_flags.dart';

/// The 50/50 hint (`mc_fixtures_platform` CONTRACT.md: `control` 10000,
/// `hint` 0, so nobody gets it unless a dev override forces it). In the
/// `hint` variant the play page offers the hint once per round; it costs 50
/// points on a correct answer, a rule the server applies too
/// (`mc_fixtures_editorial` CONTRACT.md, Scoring rule 4).
///
/// The play bloc reads it once, when the round starts: a remote fetch that
/// lands mid-round does not make the hint appear or vanish.
const Experiment triviaHint = Experiment(
  key: 'trivia_hint',
  variants: [ExperimentVariant('control', 10000), ExperimentVariant('hint', 0)],
  description: 'Offers the 50/50 hint once per trivia round.',
);

/// The variant that offers the hint.
const String triviaHintOn = 'hint';
