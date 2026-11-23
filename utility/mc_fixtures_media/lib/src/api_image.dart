/// Size classes of one image, named as in the contract (`portrait_medium`).
///
/// The placeholder art has one picture per image, so every variant resolves to
/// the same asset: the variant only tells the UI what box it is drawn into.
enum ImageVariant {
  portraitSmall('portrait_small', 50, 75),
  portraitMedium('portrait_medium', 100, 150),
  portraitLarge('portrait_large', 150, 225),
  standard('standard', 100, 100),
  landscape('landscape', 175, 100);

  const ImageVariant(this.wireName, this.width, this.height);

  /// The name in JSON.
  final String wireName;
  final int width;
  final int height;

  static ImageVariant fromWire(String name) => values.firstWhere(
    (v) => v.wireName == name,
    orElse: () => throw FormatException('Unknown image variant', name),
  );
}

/// An image reference as the API sends it: a path plus a variant.
///
/// A real backend would send an `https://` path; the mocked backend sends
/// `mock-asset://<set>/<id>`. This type moves to `mc_media` when that package
/// lands (plan 01 §6.4, U39); its JSON shape stays.
final class ApiImage {
  const ApiImage({
    required this.path,
    this.variant = ImageVariant.portraitMedium,
  });

  factory ApiImage.fromJson(Map<String, Object?> json) => ApiImage(
    path: json['path']! as String,
    variant: ImageVariant.fromWire(json['variant']! as String),
  );

  /// `mock-asset://characters/017` for bundled placeholders.
  final String path;
  final ImageVariant variant;

  Map<String, Object?> toJson() => {'path': path, 'variant': variant.wireName};

  @override
  bool operator ==(Object other) =>
      other is ApiImage && other.path == path && other.variant == variant;

  @override
  int get hashCode => Object.hash(path, variant);

  @override
  String toString() => 'ApiImage($path, ${variant.wireName})';
}
