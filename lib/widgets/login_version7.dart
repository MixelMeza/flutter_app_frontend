import 'dart:ui';

import 'package:flutter/material.dart';
import '../theme.dart';

// Note: gradient interpolation is handled via AnimatedContainer for robust,
// native decoration tweening. We avoid a custom GradientTween to keep
// behavior predictable across Flutter versions.

/// LoginVersion7
/// Widget de login modular y configurable.
class LoginVersion7 extends StatefulWidget {
  final Widget? logo;
  final String appName;
  final bool? isDarkMode; // si null, usa Theme.of(context)
  final ValueChanged<bool>? onToggleTheme;
  final Future<void> Function(String email, String password) onLogin;
  final VoidCallback? onForgotPassword;
  final VoidCallback? onRegister;
  final String? initialEmail;

  const LoginVersion7({
    Key? key,
    this.logo,
    required this.appName,
    this.isDarkMode,
    this.onToggleTheme,
    required this.onLogin,
    this.onForgotPassword,
    this.onRegister,
    this.initialEmail,
  }) : super(key: key);

  @override
  State<LoginVersion7> createState() => _LoginVersion7State();
}

class _LoginVersion7State extends State<LoginVersion7> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();
  bool _obscure = true;
  bool _emailReadOnly = false;
  bool _submitting = false;
  String? _emailError;
  String? _passwordError;
  // No explicit controllers: use AnimatedContainer for smooth, native
  // gradient decoration transitions.

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailCtrl.text = widget.initialEmail!;
      _emailReadOnly = true;
    }
    // no display name shown on login per UX preference (only show errors)
  }

  // No initState needed for background animation when using AnimatedContainer
  bool _forgotPressed = false;
  bool _registerPressed = false;

  @override
  Widget build(BuildContext context) {
    final inheritedDark = Theme.of(context).brightness == Brightness.dark;
    final isDark = widget.isDarkMode ?? inheritedDark;

    // Same diagonal direction for both modes
    final begin = Alignment.topLeft;
    final end = Alignment.bottomRight;

    final lightGradient = LinearGradient(begin: begin, end: end, colors: [AppColors.midnightBlue, AppColors.lightBlue]);

  // Derive a muted maroon (less saturated, slightly lighter) for dark mode
  // We avoid shifting hue toward green/teal — keep the maroon hue but soften it.
  final h = HSLColor.fromColor(AppColors.maroon);
  final derivedMutedMaroon = h
    .withSaturation((h.saturation * 0.48).clamp(0.0, 1.0))
    .withLightness((h.lightness * 1.02).clamp(0.0, 1.0))
    .toColor()
    .withAlpha((0.94 * 255).round());

  final darkGradient = LinearGradient(begin: begin, end: end, colors: [AppColors.midnightBlue, derivedMutedMaroon]);

    final bgGradient = isDark ? darkGradient : lightGradient;

    // cardColor is computed inline where used
    final logoBg = AppColors.alabaster;
    final titleColor = isDark ? AppColors.alabaster : AppColors.midnightBlue;
  // Use alabaster for borders in dark mode (per request). Use a muted maroon for
  // selectable accents (buttons) but not too intense.
  final subtitleColor = isDark ? AppColors.tan : AppColors.alabaster.withAlpha((0.9 * 255).round());
  final buttonColor = isDark ? derivedMutedMaroon : AppColors.midnightBlue;

    return Scaffold(
      body: AnimatedContainer(
        width: double.infinity,
        height: double.infinity,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(gradient: bgGradient),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: LayoutBuilder(builder: (context, constraints) {
              final double maxWidth = constraints.maxWidth >= 1000
                  ? 760.0
                  : (constraints.maxWidth >= 768 ? 640.0 : (constraints.maxWidth >= 430 ? 460.0 : 360.0));

              return ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Stack(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Header
                        Column(
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: logoBg,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: const Color.fromRGBO(0, 0, 0, 0.25), blurRadius: 12, offset: const Offset(0, 6)),
                                ],
                              ),
                              child: Center(
                                child: widget.logo ?? Icon(Icons.home, size: 44, color: isDark ? AppColors.alabaster : AppColors.midnightBlue),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(widget.appName, style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: titleColor)),
                            const SizedBox(height: 6),
                            // intentionally do not show display name on login
                            Text('Bienvenido de nuevo', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: subtitleColor)),
                          ],
                        ),

                        const SizedBox(height: 22),

                        // Card with controlled blur and better padding/opacity in dark mode
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            // Slightly reduced blur to avoid washed-out text
                            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 450),
                              curve: Curves.easeInOut,
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
                                decoration: BoxDecoration(
                                color: isDark ? AppColors.midnightBlue.withAlpha((0.64 * 255).round()) : AppColors.alabaster.withAlpha((0.98 * 255).round()),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark ? const Color.fromRGBO(0,0,0,0.36) : const Color.fromRGBO(0,0,0,0.12),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: _buildForm(context, isDark, buttonColor),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Theme toggle in the top-right corner of the constrained area
                    Positioned(
                      right: 0,
                      top: 0,
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Semantics(
                            button: true,
                            label: isDark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
                            child: IconButton(
                              onPressed: () {
                                widget.onToggleTheme?.call(!isDark);
                              },
                              tooltip: isDark ? 'Modo claro' : 'Modo oscuro',
                              icon: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 350),
                                transitionBuilder: (child, animation) {
                                  return RotationTransition(
                                    turns: Tween<double>(begin: 0.75, end: 1.0).animate(animation),
                                    child: FadeTransition(opacity: animation, child: child),
                                  );
                                },
                                child: isDark ? const Icon(Icons.nights_stay, key: ValueKey('moon')) : const Icon(Icons.wb_sunny, key: ValueKey('sun')),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, bool isDark, Color buttonColor) {
    final borderColor = isDark ? AppColors.alabaster : AppColors.midnightBlue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Email
        Semantics(
          label: 'Campo de correo electrónico',
          hint: 'Ingrese su correo electrónico',
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _emailCtrl,
                    focusNode: _emailFocus,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _passFocus.requestFocus(),
                    style: TextStyle(color: isDark ? AppColors.alabaster : AppColors.midnightBlue),
                    readOnly: _emailReadOnly,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.mail_outline, color: borderColor.withAlpha((0.9 * 255).round())),
                      labelText: 'Email',
                      labelStyle: TextStyle(color: isDark ? AppColors.alabaster.withAlpha((0.9 * 255).round()) : AppColors.midnightBlue),
                      hintText: 'correo@ejemplo.com',
                        hintStyle: TextStyle(color: isDark ? AppColors.alabaster.withAlpha((0.75 * 255).round()) : AppColors.midnightBlue.withAlpha((0.7 * 255).round())),
                      errorText: _emailError,
                      filled: true,
                      fillColor: Colors.transparent,
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: borderColor.withAlpha((0.12 * 255).round()))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: borderColor, width: 2)),
                    ),
                  ),
                ),
                if (_emailReadOnly) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _emailReadOnly = false;
                        // allow editing and focus the field
                        FocusScope.of(context).requestFocus(_emailFocus);
                      });
                    },
                    child: const Text('Cambiar'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Password
        Semantics(
          label: 'Campo de contraseña',
          hint: 'Ingrese su contraseña',
          child: SizedBox(
            height: 64,
                child: TextFormField(
              controller: _passCtrl,
              focusNode: _passFocus,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              style: TextStyle(color: isDark ? AppColors.alabaster : AppColors.midnightBlue),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.lock_outline, color: borderColor.withAlpha((0.9 * 255).round())),
                labelText: 'Contraseña',
                labelStyle: TextStyle(color: isDark ? AppColors.alabaster.withAlpha((0.9 * 255).round()) : AppColors.midnightBlue),
                hintText: '••••••••',
                  hintStyle: TextStyle(color: isDark ? AppColors.alabaster.withAlpha((0.75 * 255).round()) : AppColors.midnightBlue.withAlpha((0.7 * 255).round())),
                    errorText: _passwordError,
                filled: true,
                fillColor: Colors.transparent,
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: borderColor.withAlpha((0.12 * 255).round()))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: borderColor, width: 2)),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: borderColor.withAlpha((0.9 * 255).round())),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Semantics(
            button: true,
            label: 'Olvidaste contraseña',
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (_) => setState(() => _forgotPressed = true),
              onTapUp: (_) {
                setState(() => _forgotPressed = false);
                widget.onForgotPassword?.call();
              },
              onTapCancel: () => setState(() => _forgotPressed = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: _forgotPressed ? (isDark ? buttonColor.withAlpha((0.22 * 255).round()) : buttonColor.withAlpha((0.08 * 255).round())) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _forgotPressed
                      ? [BoxShadow(color: buttonColor.withAlpha((0.28 * 255).round()), blurRadius: 14, spreadRadius: 1)]
                      : [],
                ),
                child: Text('¿Olvidaste tu contraseña?', style: TextStyle(color: isDark ? AppColors.alabaster : AppColors.midnightBlue)),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),
        // Button
        SizedBox(
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: AppColors.alabaster,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _submitting ? null : _submit,
            child: _submitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Iniciar Sesión', style: TextStyle(fontSize: 18)),
          ),
        ),

        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('¿Aún no tienes cuenta?', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(width: 6),
            Semantics(
              button: true,
              label: 'Registrarse',
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: (_) => setState(() => _registerPressed = true),
                onTapUp: (_) {
                  setState(() => _registerPressed = false);
                  widget.onRegister?.call();
                },
                onTapCancel: () => setState(() => _registerPressed = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                    color: _registerPressed ? (isDark ? buttonColor.withAlpha((0.22 * 255).round()) : buttonColor.withAlpha((0.08 * 255).round())) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: _registerPressed ? [BoxShadow(color: buttonColor.withAlpha((0.28 * 255).round()), blurRadius: 14, spreadRadius: 1)] : [],
                  ),
                  child: Text('Registrarse', style: TextStyle(color: isDark ? AppColors.alabaster : AppColors.midnightBlue)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _submit() {
    if (_submitting) return;
    setState(() {
      _emailError = null;
      _passwordError = null;
      _submitting = true;
    });

    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    // Await the parent's async login; let it throw ApiException on failure
    widget.onLogin(email, pass).then((_) {
      if (!mounted) return;
      setState(() => _submitting = false);
    }).catchError((err) {
      if (!mounted) return;
      // Política solicitada: no mostrar textos largos. Solo:
      // - "Contraseña incorrecta" para cualquier error de credenciales u otro
      // - Error de red mínimo si es claramente un problema de conexión
      final errStr = err.toString().toLowerCase();
      final isNetwork = errStr.contains('connection') || errStr.contains('timeout');
      setState(() {
        _submitting = false;
        _emailError = null;
        _passwordError = isNetwork ? 'Error de red. Intenta nuevamente.' : 'Contraseña incorrecta';
      });
    });
  }
}
