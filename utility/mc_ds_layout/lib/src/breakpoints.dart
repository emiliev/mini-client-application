/// Width classes (logical pixels) and the grid columns each one gets.
enum McWidthClass {
  /// Phones: under 600.
  compact(2),

  /// Large phones and small tablets: 600 to under 1024.
  medium(3),

  /// Tablets and desktop: 1024 and up.
  expanded(4);

  const McWidthClass(this.columns);

  final int columns;

  static const double mediumStart = 600;
  static const double expandedStart = 1024;

  static McWidthClass of(double width) {
    if (width >= expandedStart) {
      return expanded;
    }
    if (width >= mediumStart) {
      return medium;
    }
    return compact;
  }
}
