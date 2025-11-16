import 'package:flutter/material.dart';
import '../theme.dart';

/// A circular leading icon used in ListTiles and info rows.
/// It adapts to the current theme for background and icon colors.
class LeadingIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;

  const LeadingIcon(
    this.icon, {
    super.key,
    this.size = 36.0,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = backgroundColor ??
      (isDark ? const Color.fromRGBO(239, 232, 223, 0.06) : AppColors.tan.withAlpha((0.12 * 255).round()));
    final fg = iconColor ?? (isDark ? AppColors.tan : AppColors.midnightBlue);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color.fromRGBO(0, 0, 0, 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Center(child: Icon(icon, color: fg, size: size * 0.56)),
    );
  }
}
