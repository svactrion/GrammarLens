/// The in-app text size setting. Its stored and analytics values are the
/// names (`small`, `medium`, `large`); only the scale behind each changed.
///
/// 1.2.0 final pass (owner, after trying Large on the device): the app
/// opens at what used to be Large. The scale moved one step up rather than
/// the default moving to the end: Small is the old Medium (1.1), Medium,
/// still the default, the old Large (1.2), and Large one more step at the
/// same ratio (1.2 × 1.2 / 1.1 = 1.309, rounded to 1.31). The system's
/// Dynamic Type still applies on top.
enum AppTextSize {
  small,
  medium,
  large;

  double get scaleFactor => switch (this) {
        AppTextSize.small => 1.1,
        AppTextSize.medium => 1.2,
        AppTextSize.large => 1.31,
      };
}

extension AppTextSizeJson on AppTextSize {
  String toJson() => name;

  static AppTextSize fromJson(String? value) => switch (value) {
        'small' => AppTextSize.small,
        'large' => AppTextSize.large,
        _ => AppTextSize.medium,
      };
}
