import 'package:mc_feature_flags/mc_feature_flags.dart';

/// The featured section of the store home (the first flag, T-0056). Off: the
/// section is not built, so its bloc never exists and `GET v1/store/featured`
/// is never sent.
///
/// A feature declares its flags as `const` values in its own package; the
/// kit holds none. The page reads it once, when it opens (a section does not
/// come and go under the reader), through the root's `FeatureFlagsReader`.
const FeatureFlag<bool> storeHomeFeatured = FeatureFlag<bool>(
  key: 'store.home_featured',
  defaultValue: true,
  description: 'Shows the featured products section on the store home.',
  codec: BoolFlagCodec(),
);
