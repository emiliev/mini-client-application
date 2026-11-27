import 'dart:convert';

import 'package:mc_feature_flags/src/feature_flag.dart';

/// FNV-1a, 32 bit, over [bytes]: offset basis 2166136261, prime 16777619.
///
/// Written without a product above 2^41, so the result is the same on the VM
/// and in JavaScript: `h * 16777619` is `(h << 24) + h * 403` (the prime is
/// `2^24 + 403`), and `h << 24` modulo 2^32 only needs the low byte of `h`.
int fnv1a32(List<int> bytes) {
  var hash = 2166136261;
  for (final byte in bytes) {
    hash ^= byte;
    hash = (((hash & 0xFF) << 24) + hash * 403) & 0xFFFFFFFF;
  }
  return hash;
}

/// The largest weight a variant may have, declared or remote. The scaled
/// cumulative weight is `cumulative * 10000`, so with this cap and fewer than
/// 900 variants it stays under 2^53 (JavaScript's exact integers) and far
/// under 2^63. A remote weight above it is malformed.
const int maxVariantWeight = 1000000000;

/// The number of buckets a subject falls into, per experiment.
const int bucketCount = 10000;

/// The bucket (0 to 9999) of [subjectId] in [experimentKey]: FNV-1a 32 over
/// the UTF-8 bytes of `"<experimentKey>:<subjectId>"`, modulo 10000. Never
/// `String.hashCode`, which differs between runs and platforms.
int bucketOf(String experimentKey, String subjectId) =>
    fnv1a32(utf8.encode('$experimentKey:$subjectId')) % bucketCount;

/// The variant [bucket] falls into. [weights] are the relative weights of
/// [variants], in order; the cumulative weight is scaled to [bucketCount]
/// (`cumulative * 10000 ~/ total`) and the first variant whose scaled
/// cumulative weight is above [bucket] wins. A variant with weight 0 has an
/// empty interval, so it never wins. With no positive weight the first
/// variant (the control) wins.
String pickVariant(
  List<ExperimentVariant> variants,
  List<int> weights,
  int bucket,
) {
  var total = 0;
  for (final weight in weights) {
    total += weight;
  }
  if (total <= 0) {
    return variants.first.name;
  }
  var cumulative = 0;
  for (var i = 0; i < variants.length; i++) {
    cumulative += weights[i];
    if (bucket < cumulative * bucketCount ~/ total) {
      return variants[i].name;
    }
  }
  return variants.first.name;
}
