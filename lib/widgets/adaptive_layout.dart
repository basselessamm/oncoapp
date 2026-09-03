import 'package:flutter/material.dart';

/// Screen breakpoint definitions for adaptive layouts.
abstract final class Breakpoints {
  static const double mobileMax = 650;
  static const double tabletMax = 1050;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileMax;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobileMax && width < tabletMax;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletMax;
}

/// Clamps maximum width on wide displays so content does not stretch into an unreadable ribbon.
class AdaptiveContainer extends StatelessWidget {
  const AdaptiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 1100,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// An adaptive responsive grid that lays out items in 1 column (mobile),
/// 2 columns (tablet / medium desktop), or 3 columns (wide workstation displays).
class AdaptiveCardGrid extends StatelessWidget {
  const AdaptiveCardGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.spacing = 14,
    this.padding = const EdgeInsets.all(16),
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double spacing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < 850
            ? 1
            : width < 1250
                ? 2
                : 3;

        if (columns == 1) {
          return ListView.builder(
            padding: padding,
            itemCount: itemCount,
            itemBuilder: itemBuilder,
          );
        }

        // Multi-column layout using rows
        final rowCount = (itemCount / columns).ceil();

        return ListView.builder(
          padding: padding,
          itemCount: rowCount,
          itemBuilder: (context, rowIndex) {
            final startIndex = rowIndex * columns;
            return Padding(
              padding: EdgeInsets.only(bottom: spacing),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var c = 0; c < columns; c++) ...[
                    if (c > 0) SizedBox(width: spacing),
                    Expanded(
                      child: (startIndex + c < itemCount)
                          ? itemBuilder(context, startIndex + c)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
