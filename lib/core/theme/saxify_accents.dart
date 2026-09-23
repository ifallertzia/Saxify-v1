import 'package:flutter/material.dart';

/// One neon accent from the Saxify palette.
///
/// The web app (saxify.vercel.app) lets you "paint the neon across the whole
/// app" with an accent colour. The mobile app ships the same idea: a small set
/// of accents that can either rotate automatically or be pinned by the user.
@immutable
class SaxifyAccent {
  const SaxifyAccent({
    required this.id,
    required this.label,
    required this.primary,
    required this.secondary,
    required this.tint,
  });

  /// Stable key used for persistence (never reorder-dependent).
  final String id;

  /// Human readable name shown in Settings.
  final String label;

  /// Gradient start.
  final Color primary;

  /// Gradient end.
  final Color secondary;

  /// Soft, low-alpha wash used for card backgrounds / glows.
  final Color tint;

  List<Color> get gradientColors => <Color>[primary, secondary];

  LinearGradient get gradient => LinearGradient(
        colors: gradientColors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get horizontalGradient => LinearGradient(
        colors: gradientColors,
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );

  /// Same gradient but fading out — used for the hero / player backdrops.
  LinearGradient get fadeGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          primary.withValues(alpha: 0.30),
          secondary.withValues(alpha: 0.10),
          const Color(0xFF08070D).withValues(alpha: 0.0),
        ],
      );
}

/// Vivid, high-contrast accents Saxify rotates through.
///
/// Neon Violet is the signature accent; the rest are alternates so the app can
/// cycle its look every couple of minutes (or be pinned from Settings).
class SaxifyAccents {
  const SaxifyAccents._();

  static const SaxifyAccent neonViolet = SaxifyAccent(
    id: 'neon-violet',
    label: 'Neon Violet',
    primary: Color(0xFFB75AFF),
    secondary: Color(0xFF9763FF),
    tint: Color(0x2EB75AFF),
  );

  static const SaxifyAccent aquaPulse = SaxifyAccent(
    id: 'aqua-pulse',
    label: 'Aqua Pulse',
    primary: Color(0xFF0CE5F2),
    secondary: Color(0xFF62B5FF),
    tint: Color(0x2E0CE5F2),
  );

  static const SaxifyAccent cyberLime = SaxifyAccent(
    id: 'cyber-lime',
    label: 'Cyber Lime',
    primary: Color(0xFFBDFF3D),
    secondary: Color(0xFF4FEF83),
    tint: Color(0x2EBDFF3D),
  );

  static const SaxifyAccent sunsetCoral = SaxifyAccent(
    id: 'sunset-coral',
    label: 'Sunset Coral',
    primary: Color(0xFFFF6774),
    secondary: Color(0xFFFF835D),
    tint: Color(0x2EFF6774),
  );

  static const SaxifyAccent magentaFlux = SaxifyAccent(
    id: 'magenta-flux',
    label: 'Magenta Flux',
    primary: Color(0xFFFF64C8),
    secondary: Color(0xFFE05CF2),
    tint: Color(0x2EFF64C8),
  );

  static const SaxifyAccent goldRush = SaxifyAccent(
    id: 'gold-rush',
    label: 'Gold Rush',
    primary: Color(0xFFFFDA46),
    secondary: Color(0xFFFFB643),
    tint: Color(0x2EFFDA46),
  );

  static const SaxifyAccent silver = SaxifyAccent(
    id: 'silver', label: 'Silver',
    primary: Color(0xFFE8EDF5), secondary: Color(0xFFBAC8D8),
    tint: Color(0x2EE8EDF5),
  );
  static const SaxifyAccent electricBlue = SaxifyAccent(
    id: 'electric-blue', label: 'Electric Blue',
    primary: Color(0xFF72B9FF), secondary: Color(0xFF4A96FF),
    tint: Color(0x2E72B9FF),
  );
  static const SaxifyAccent vividOrange = SaxifyAccent(
    id: 'vivid-orange', label: 'Vivid Orange',
    primary: Color(0xFFFFA235), secondary: Color(0xFFFF7640),
    tint: Color(0x2EFFA235),
  );
  static const SaxifyAccent mint = SaxifyAccent(
    id: 'mint', label: 'Mint',
    primary: Color(0xFF44F2BB), secondary: Color(0xFF39D8D4),
    tint: Color(0x2E44F2BB),
  );
  static const SaxifyAccent ruby = SaxifyAccent(
    id: 'ruby', label: 'Ruby',
    primary: Color(0xFFFF658C), secondary: Color(0xFFFF4867),
    tint: Color(0x2EFF658C),
  );

  static const List<SaxifyAccent> all = <SaxifyAccent>[
    neonViolet,
    aquaPulse,
    cyberLime,
    sunsetCoral,
    magentaFlux,
    goldRush,
    silver,
    electricBlue,
    vividOrange,
    mint,
    ruby,
  ];

  static SaxifyAccent byId(String? id) {
    for (final SaxifyAccent accent in all) {
      if (accent.id == id) return accent;
    }
    return neonViolet;
  }

  static int indexOfId(String? id) {
    for (int i = 0; i < all.length; i++) {
      if (all[i].id == id) return i;
    }
    return 0;
  }
}

/// Makes the live accent reachable through `Theme.of(context)` so deep widgets
/// can paint themselves without an extra provider lookup.
@immutable
class SaxifyAccentExtension extends ThemeExtension<SaxifyAccentExtension> {
  const SaxifyAccentExtension(this.accent);

  final SaxifyAccent accent;

  @override
  SaxifyAccentExtension copyWith({SaxifyAccent? accent}) =>
      SaxifyAccentExtension(accent ?? this.accent);

  @override
  SaxifyAccentExtension lerp(covariant ThemeExtension<SaxifyAccentExtension>? other, double t) {
    if (other is! SaxifyAccentExtension) return this;
    return t < 0.5 ? this : other;
  }
}

/// Convenience accessor used across the UI.
extension SaxifyAccentX on BuildContext {
  SaxifyAccent get accent =>
      Theme.of(this).extension<SaxifyAccentExtension>()?.accent ??
      SaxifyAccents.neonViolet;
}
