import 'dart:async';

import 'package:flutter/material.dart';
import '../theme.dart';

/// Simple splash screen that shows the app logo (assets/logo.png by default)
/// and the app name, animates in, then calls [onFinish].
class SplashScreen extends StatefulWidget {
  final String logoAssetPath;
  final String appName;
  final Duration duration;
  final VoidCallback? onFinish;

  const SplashScreen({
    super.key,
    this.logoAssetPath = 'assets/logo.png',
    this.appName = 'LivUp',
    this.duration = const Duration(milliseconds: 1400),
    this.onFinish,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    _ctrl.forward();

    // Call onFinish after provided duration (gives time for the animation)
    Timer(widget.duration, () {
      widget.onFinish?.call();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo asset with padding and smaller visual size so it doesn't look oversized
                Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: SizedBox(
                    width: 140,
                    height: 140,
                    child: Image.asset(
                      widget.logoAssetPath,
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => Container(
                        decoration: BoxDecoration(
                          color: AppColors.midnightBlue,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.apartment,
                          size: 72,
                          color: AppColors.alabaster,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.appName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.midnightBlue,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
