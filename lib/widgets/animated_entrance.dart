import 'package:flutter/material.dart';

/// Staggered animated entrance for list items and cards.
///
/// Respects accessibility reduced-motion settings by bypassing animation when
/// [MediaQuery.of(context).disableAnimations] is enabled.
class AnimatedEntrance extends StatelessWidget {
  const AnimatedEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 320),
    this.offsetY = 16.0,
  });

  final Widget child;
  final int index;
  final Duration duration;
  final double offsetY;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return child;
    }

    // Delay entry slightly per index (capped at 360ms)
    final delayMs = (index * 35).clamp(0, 360);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: duration + Duration(milliseconds: delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1.0 - value) * offsetY),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// A desktop-friendly interactive card container that elevates and highlights
/// subtly on mouse hover with pointer cursor.
class InteractiveHoverCard extends StatefulWidget {
  const InteractiveHoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 14.0,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;

  @override
  State<InteractiveHoverCard> createState() => _InteractiveHoverCardState();
}

class _InteractiveHoverCardState extends State<InteractiveHoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hoverBorderColor = isDark
        ? theme.colorScheme.primary.withValues(alpha: 0.45)
        : theme.colorScheme.primary.withValues(alpha: 0.35);

    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _isHovered ? -2.5 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.45)
                          : Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const [],
            border: Border.all(
              color: _isHovered
                  ? hoverBorderColor
                  : theme.cardTheme.shape is RoundedRectangleBorder
                      ? (theme.cardTheme.shape as RoundedRectangleBorder)
                          .side
                          .color
                      : theme.colorScheme.outline,
              width: _isHovered ? 1.4 : 1.0,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
