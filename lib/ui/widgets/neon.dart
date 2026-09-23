import 'dart:ui';

import 'package:flutter/material.dart';
import '../../core/theme/saxify_fonts.dart';

import '../../core/theme/saxify_accents.dart';
import '../../core/theme/saxify_theme.dart';

/// Text painted with the live accent gradient — the site's neon headlines.
class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, this.style, this.accent});

  final String text;
  final TextStyle? style;
  final SaxifyAccent? accent;

  @override
  Widget build(BuildContext context) {
    final SaxifyAccent a = accent ?? context.accent;
    return ShaderMask(
      shaderCallback: (Rect bounds) => a.horizontalGradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Text(
        text,
        style: (style ?? const TextStyle()).copyWith(color: Colors.white),
      ),
    );
  }
}

/// Rail heading: title, optional blurb, optional "Show all" action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(20, 26, 12, 12),
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(title,
                    style: SaxifyFonts.display(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: SaxifyColors.textPrimary,
                      letterSpacing: -0.3,
                    )),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(subtitle!,
                      style: const TextStyle(
                          fontSize: 12.5, color: SaxifyColors.textMuted)),
                ],
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: context.accent.primary,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                textStyle: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              child: Text(actionLabel!.toUpperCase()),
            ),
        ],
      ),
    );
  }
}

/// The card surface everything sits on.
class NeonCard extends StatelessWidget {
  const NeonCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.radius = SaxifyTheme.radiusMd,
    this.background,
    this.borderColor,
    this.glow = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double radius;
  final Color? background;
  final Color? borderColor;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final Color border = borderColor ?? SaxifyColors.border;
    final BoxDecoration decoration = BoxDecoration(
      color: background ?? SaxifyColors.card,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border),
      boxShadow: glow
          ? <BoxShadow>[
              BoxShadow(
                color: context.accent.primary.withValues(alpha: 0.18),
                blurRadius: 26,
                spreadRadius: -6,
              ),
            ]
          : null,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        splashColor: context.accent.primary.withValues(alpha: 0.10),
        highlightColor: context.accent.primary.withValues(alpha: 0.05),
        child: Ink(decoration: decoration, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// Pill button with the accent gradient (filled) or an outline (ghost).
class NeonButton extends StatelessWidget {
  const NeonButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.filled = true,
    this.expand = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool filled;
  final bool expand;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final SaxifyAccent a = context.accent;
    final double height = compact ? 38 : 48;

    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: compact ? 16 : 18, color: filled ? Colors.black : a.primary),
          const SizedBox(width: 8),
        ],
        Flexible(child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: compact ? 12.5 : 14,
            fontWeight: FontWeight.w700,
            color: filled ? Colors.black : a.primary,
            letterSpacing: 0.2,
          ),
        )),
      ],
    );

    final BorderRadius radius = BorderRadius.circular(SaxifyTheme.radiusXl);

    return SizedBox(
      width: expand ? double.infinity : null,
      height: height,
      child: Opacity(
        opacity: onPressed == null ? 0.45 : 1,
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: radius,
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    gradient: filled
                        ? a.gradient
                        : LinearGradient(
                            colors: <Color>[
                              Colors.white.withValues(alpha: 0.15),
                              a.primary.withValues(alpha: 0.07),
                            ],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                    border: Border.all(color: filled
                        ? Colors.white.withValues(alpha: 0.42)
                        : Colors.white.withValues(alpha: 0.24)),
                    boxShadow: filled ? <BoxShadow>[
                      BoxShadow(color: a.primary.withValues(alpha: 0.27),
                        blurRadius: 18, offset: const Offset(0, 8), spreadRadius: -6),
                    ] : null,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 22),
                    child: content,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty rail / empty tab placeholder.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final SaxifyAccent a = context.accent;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    a.primary.withValues(alpha: 0.22),
                    a.secondary.withValues(alpha: 0.08),
                  ],
                ),
                border: Border.all(color: a.primary.withValues(alpha: 0.25)),
              ),
              child: Icon(icon, size: 32, color: a.primary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: SaxifyFonts.display(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: SaxifyColors.textPrimary,
              ),
            ),
            if (message != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: SaxifyColors.textMuted, height: 1.5),
              ),
            ],
            if (actionLabel != null) ...<Widget>[
              const SizedBox(height: 22),
              NeonButton(label: actionLabel!, onPressed: onAction, compact: true),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shimmering placeholders while a rail loads.
class LoadingRail extends StatelessWidget {
  const LoadingRail({super.key, this.itemCount = 5, this.height = 64});

  final int itemCount;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (int i = 0; i < itemCount; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: <Widget>[
                _ShimmerBox(
                    width: height - 8, height: height - 8, radius: 10),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _ShimmerBox(width: 190, height: 11, radius: 6),
                      const SizedBox(height: 8),
                      _ShimmerBox(width: 110, height: 9, radius: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({required this.width, required this.height, this.radius = 8});

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: SaxifyColors.surfaceAlt,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Thin divider with a neon hint at the start.
class NeonDivider extends StatelessWidget {
  const NeonDivider({super.key, this.height = 1});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            context.accent.primary.withValues(alpha: 0.5),
            SaxifyColors.border,
            SaxifyColors.border.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}
