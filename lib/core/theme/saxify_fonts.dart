import 'package:flutter/material.dart';

/// Inter is bundled under the SIL Open Font License (assets/fonts/OFL.txt).
/// No text style downloads a font at runtime; first launch works offline.
class SaxifyFonts {
  const SaxifyFonts._();

  static const String family = 'Inter';

  static TextTheme textTheme(TextTheme base) => base.apply(fontFamily: family);

  static TextStyle display({
    TextStyle? textStyle,
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) => (textStyle ?? const TextStyle()).copyWith(
    fontFamily: family,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}
