import 'package:flutter/material.dart';

/// Browse-category colours are intentionally independent of the chosen theme
/// accent. Adjacent grid tiles never repeat (including on a Silver theme).
class CategoryPalette {
  const CategoryPalette._();

  static const List<Color> colors = <Color>[
    Color(0xFFB91C5C), Color(0xFF116E78), Color(0xFF5236B8),
    Color(0xFFBB4C15), Color(0xFF087F5B), Color(0xFFAA238C),
    Color(0xFF2455A4), Color(0xFFAD2835), Color(0xFF26652E),
    Color(0xFFCE7E0B), Color(0xFF7553B5), Color(0xFF1B849B),
    Color(0xFFB42D74), Color(0xFF5F6B19), Color(0xFF9F4532),
    Color(0xFF3154C3), Color(0xFF147B6A), Color(0xFF9635A8),
    Color(0xFFBF632D), Color(0xFF5A52AC), Color(0xFF478020),
    Color(0xFFB83152), Color(0xFF167EAA), Color(0xFF85451A),
  ];

  static Color at(int index) => colors[index % colors.length];

  static Color forKey(String key) {
    int hash = 0;
    for (final int unit in key.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return at(hash);
  }

  static Color on(Color background) =>
      background.computeLuminance() > 0.35 ? Colors.black : Colors.white;
}
