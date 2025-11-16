import 'package:flutter/material.dart';
import '../theme.dart';

/// Reusable styled card that mirrors the app theme's card colors, radius and soft shadow.
class StyledCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const StyledCard({Key? key, required this.child, this.padding = const EdgeInsets.all(16), this.margin = const EdgeInsets.symmetric(vertical: 8, horizontal: 12)}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.cardColor;
    final radius = BorderRadius.circular(AppTheme.kBorderRadius);

    // Softer, adaptive shadow: light theme uses a subtle black shadow, dark theme uses a faint light overlay
    final boxShadow = theme.brightness == Brightness.dark
        ? [
            BoxShadow(
              color: const Color.fromRGBO(255, 255, 255, 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
        : [
            BoxShadow(
              color: const Color.fromRGBO(0, 0, 0, 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ];

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        boxShadow: boxShadow,
      ),
      child: child,
    );
  }
}
