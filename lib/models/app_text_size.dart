enum AppTextSize {
  small,
  medium,
  large;

  double get scaleFactor => switch (this) {
        AppTextSize.small => 1.0,
        AppTextSize.medium => 1.1,
        AppTextSize.large => 1.2,
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
