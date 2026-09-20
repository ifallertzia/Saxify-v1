import 'package:flutter/material.dart';

/// One neon accent from the Sidify palette.
///
/// The web app (sidify.vercel.app) lets you "paint the neon across the whole
/// app" with an accent colour. The mobile app ships the same idea: a small set
/// of accents that can either rotate automatically or be pinned by the user.
@immutable
class SidifyAccent {
  const SidifyAccent({
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

/// The 6 accents Sidify rotates through.
///
/// Neon Violet is the signature accent; the rest are alternates so the app can
/// cycle its look every couple of minutes (or be pinned from Settings).
class SidifyAccents {
  const SidifyAccents._();

  static const SidifyAccent neonViolet = SidifyAccent(
    id: 'neon-violet',
    label: 'Neon Violet',
    primary: Color(0xFFA855F7),
    secondary: Color(0xFF6366F1),
    tint: Color(0x2EA855F7),
  );

  static const SidifyAccent aquaPulse = SidifyAccent(
    id: 'aqua-pulse',
    label: 'Aqua Pulse',
    primary: Color(0xFF22D3EE),
    secondary: Color(0xFF3B82F6),
    tint: Color(0x2E22D3EE),
  );

  static const SidifyAccent cyberLime = SidifyAccent(
    id: 'cyber-lime',
    label: 'Cyber Lime',
    primary: Color(0xFFA3E635),
    secondary: Color(0xFF22C55E),
    tint: Color(0x2EA3E635),
  );

  static const SidifyAccent sunsetCoral = SidifyAccent(
    id: 'sunset-coral',
    label: 'Sunset Coral',
    primary: Color(0xFFFB7185),
    secondary: Color(0xFFF43F5E),
    tint: Color(0x2EFB7185),
  );

  static const SidifyAccent magentaFlux = SidifyAccent(
    id: 'magenta-flux',
    label: 'Magenta Flux',
    primary: Color(0xFFF472B6),
    secondary: Color(0xFFA21CAF),
    tint: Color(0x2EF472B6),
  );

  static const SidifyAccent goldRush = SidifyAccent(
    id: 'gold-rush',
    label: 'Gold Rush',
    primary: Color(0xFFFCD34D),
    secondary: Color(0xFFF59E0B),
    tint: Color(0x2EFCD34D),
  );

  static const List<SidifyAccent> all = <SidifyAccent>[
    neonViolet,
    aquaPulse,
    cyberLime,
    sunsetCoral,
    magentaFlux,
    goldRush,
  ];

  static SidifyAccent byId(String? id) {
    for (final SidifyAccent accent in all) {
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
/// Makes the live accent reachable through `Theme.of(context)` so deep widgets
/// can paint themselves without an extra provider lookup.
@immutable
class SidifyAccentExtension extends ThemeExtension<SidifyAccentExtension> {
  const SidifyAccentExtension(this.accent);

  final SidifyAccent accent;

  @override
  SidifyAccentExtension copyWith({SidifyAccent? accent}) =>
      SidifyAccentExtension(accent ?? this.accent);

  @override
  SidifyAccentExtension lerp(covariant ThemeExtension<SidifyAccentExtension>? other, double t) {
    if (other is! SidifyAccentExtension) return this;
    return t < 0.5 ? this : other;
  }
}

/// Convenience accessor used across the UI.
extension SidifyAccentX on BuildContext {
  SidifyAccent get accent =>
      Theme.of(this).extension<SidifyAccentExtension>()?.accent ??
      SidifyAccents.neonViolet;
}
