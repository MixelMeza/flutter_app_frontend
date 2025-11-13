import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';

class RegisterVersion7 extends StatefulWidget {
  final Widget? logo;
  final String appName;
  final bool? isDarkMode;
  final ValueChanged<bool>? onToggleTheme;
  // now returns a full map of the registration data
  final void Function(Map<String, dynamic> data) onRegister;
  final VoidCallback? onLogin;

  const RegisterVersion7({
    Key? key,
    this.logo,
    required this.appName,
    this.isDarkMode,
    this.onToggleTheme,
    required this.onRegister,
    this.onLogin,
  }) : super(key: key);

  @override
  State<RegisterVersion7> createState() => _RegisterVersion7State();
}

class _RegisterVersion7State extends State<RegisterVersion7> {
  final _nameCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _dniCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _telefonoApoderadoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  final _fechaCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  // form key
  final _formKey = GlobalKey<FormState>();
  // track which fields the user interacted with (touched)
  final Map<String, bool> _touched = {};
  // dropdowns / selects
  String _tipoDocumento = 'DNI';
  String? _sexo;
  String? _rol; // 'inquilino' | 'propietario'
  int? _rolId; // numeric id expected by backend (inferred)
  DateTime? _fechaNacimiento;
  bool _showErrors = false; // controls whether validation errors are shown

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _fechaCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  // mark a field as touched (only triggers a rebuild the first time)
  void _markTouched(String key) {
    if (_touched[key] == true) return;
    setState(() {
      _touched[key] = true;
    });
  }

  bool _shouldShowError(String key) {
    return _showErrors || (_touched[key] ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final inheritedDark = Theme.of(context).brightness == Brightness.dark;
    final isDark = widget.isDarkMode ?? inheritedDark;
    final begin = Alignment.topLeft;
    final end = Alignment.bottomRight;
    final lightGradient = LinearGradient(begin: begin, end: end, colors: [AppColors.midnightBlue, AppColors.lightBlue]);
    final h = HSLColor.fromColor(AppColors.maroon);
    final derivedMutedMaroon = h.withSaturation((h.saturation * 0.48).clamp(0.0, 1.0)).withLightness((h.lightness * 1.02).clamp(0.0, 1.0)).toColor().withOpacity(0.94);
    final darkGradient = LinearGradient(begin: begin, end: end, colors: [AppColors.midnightBlue, derivedMutedMaroon]);
    final bgGradient = isDark ? darkGradient : lightGradient;
    final logoBg = AppColors.alabaster;
    final titleColor = isDark ? AppColors.alabaster : AppColors.midnightBlue;
    final subtitleColor = isDark ? AppColors.tan : AppColors.alabaster.withOpacity(0.9);
    final buttonColor = isDark ? derivedMutedMaroon : AppColors.midnightBlue;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AnimatedContainer(
        width: double.infinity,
        height: double.infinity,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(gradient: bgGradient),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 28, 20, 28 + MediaQuery.of(context).viewInsets.bottom),
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
                                  BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 6)),
                                ],
                              ),
                              child: Center(
                                child: widget.logo ?? Icon(Icons.home, size: 44, color: isDark ? AppColors.alabaster : AppColors.midnightBlue),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(widget.appName, style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: titleColor)),
                            const SizedBox(height: 6),
                            Text('Crea tu cuenta', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: subtitleColor)),
                          ],
                        ),
                        const SizedBox(height: 22),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 450),
                              curve: Curves.easeInOut,
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.midnightBlue.withOpacity(0.64) : AppColors.alabaster.withOpacity(0.98),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark ? Colors.black.withOpacity(0.36) : Colors.black.withOpacity(0.12),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Form(
                                key: _formKey,
                                // We handle per-field error visibility with `_touched` and `_showErrors`.
                                // Disable the global autovalidation to avoid validating the entire form
                                // on any single interaction (which made everything turn red when using a selector).
                                // Run validators continuously, but each field's validator
                                // will only return an error when that field is marked
                                // touched or when `_showErrors` is true (after submit).
                                autovalidateMode: AutovalidateMode.always,
                                child: _buildForm(context, isDark, buttonColor),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Theme toggle in the top-right corner
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
        // Nombre y Apellido (datos personales - vertical)
        TextFormField(
          controller: _nameCtrl,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.person_outline, color: borderColor.withOpacity(0.9)),
            labelText: 'Nombre *',
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor.withOpacity(0.12))),
          ),
          onChanged: (_) => _markTouched('nombre'),
          validator: (v) {
            if (!_shouldShowError('nombre')) return null;
            return (v == null || v.trim().isEmpty) ? 'Ingrese nombre' : null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _apellidoCtrl,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.person, color: borderColor.withOpacity(0.9)),
            labelText: 'Apellido *',
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor.withOpacity(0.12))),
          ),
          onChanged: (_) => _markTouched('apellido'),
          validator: (v) {
            if (!_shouldShowError('apellido')) return null;
            return (v == null || v.trim().isEmpty) ? 'Ingrese apellido' : null;
          },
        ),
        const SizedBox(height: 12),

        // Documento (tipo + dni) - responsive
        LayoutBuilder(builder: (ctx, constraints) {
          final narrow = constraints.maxWidth < 520;
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: _tipoDocumento,
                  items: const [
                    DropdownMenuItem(value: 'DNI', child: Text('DNI')),
                    DropdownMenuItem(value: 'Pasaporte', child: Text('Pasaporte')),
                    DropdownMenuItem(value: 'CE', child: Text('Carnet Ext')),
                  ],
                  onChanged: (v) {
                    _markTouched('tipo_documento');
                    setState(() => _tipoDocumento = v ?? 'DNI');
                  },
                  decoration: InputDecoration(labelText: 'Tipo documento', prefixIcon: Icon(Icons.badge, color: borderColor.withOpacity(0.9)), isDense: true, prefixIconConstraints: BoxConstraints(minWidth: 36, minHeight: 36)),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _dniCtrl,
                  onChanged: (_) => _markTouched('dni'),
                  decoration: InputDecoration(labelText: 'Número documento *', prefixIcon: Icon(Icons.document_scanner, color: borderColor.withOpacity(0.9)), isDense: true, prefixIconConstraints: BoxConstraints(minWidth: 36, minHeight: 36)),
                  validator: (v) {
                    if (!_shouldShowError('dni')) return null;
                    return (v == null || v.trim().isEmpty) ? 'Ingrese documento' : null;
                  },
                ),
              ],
            );
          } else {
            return Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _tipoDocumento,
                    items: const [
                      DropdownMenuItem(value: 'DNI', child: Text('DNI')),
                      DropdownMenuItem(value: 'Pasaporte', child: Text('Pasaporte')),
                      DropdownMenuItem(value: 'CE', child: Text('Carnet Ext')),
                    ],
                    onChanged: (v) {
                      _markTouched('tipo_documento');
                      setState(() => _tipoDocumento = v ?? 'DNI');
                    },
                    decoration: InputDecoration(labelText: 'Tipo documento', prefixIcon: Icon(Icons.badge, color: borderColor.withOpacity(0.9)), isDense: true, prefixIconConstraints: BoxConstraints(minWidth: 36, minHeight: 36)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: _dniCtrl,
                    onChanged: (_) => _markTouched('dni'),
                    decoration: InputDecoration(labelText: 'Número documento *', prefixIcon: Icon(Icons.document_scanner, color: borderColor.withOpacity(0.9)), isDense: true, prefixIconConstraints: BoxConstraints(minWidth: 36, minHeight: 36)),
                    validator: (v) {
                      if (!_shouldShowError('dni')) return null;
                      return (v == null || v.trim().isEmpty) ? 'Ingrese documento' : null;
                    },
                  ),
                ),
              ],
            );
          }
        }),
        const SizedBox(height: 12),

        // Email (dato personal)
        TextFormField(
          controller: _emailCtrl,
          onChanged: (_) => _markTouched('email'),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.email_outlined, color: borderColor.withOpacity(0.9)),
            labelText: 'Email *',
            isDense: true,
            prefixIconConstraints: BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (!_shouldShowError('email')) return null;
            if (v == null || v.trim().isEmpty) return 'Ingrese email';
            final emailReg = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");
            return emailReg.hasMatch(v.trim()) ? null : 'Email inválido';
          },
        ),

        const SizedBox(height: 12),

        // Fecha nacimiento y sexo (responsive)
        LayoutBuilder(builder: (ctx, constraints) {
          final narrow = constraints.maxWidth < 520;
          if (narrow) {
            return Column(
              children: [
                TextFormField(
                  controller: _fechaCtrl,
                  readOnly: true,
                  onTap: () async {
                    _markTouched('fecha_nacimiento');
                    final now = DateTime.now();
                    final initial = _fechaNacimiento ?? DateTime(now.year - 18);
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: DateTime(1900),
                      lastDate: now,
                      locale: const Locale('es', 'ES'),
                    );
                    if (picked != null) {
                      setState(() {
                        _fechaNacimiento = picked;
                        _fechaCtrl.text = DateFormat('dd/MM/yyyy').format(picked.toLocal());
                      });
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Fecha nacimiento *',
                    hintText: 'Seleccionar',
                    prefixIcon: Icon(Icons.calendar_today, color: borderColor.withOpacity(0.9)),
                    isDense: true,
                    prefixIconConstraints: BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                  validator: (_) {
                    if (!_shouldShowError('fecha_nacimiento')) return null;
                    return _fechaNacimiento == null ? 'Seleccione fecha' : null;
                  },
                ),
                const SizedBox(height: 8),
                Builder(builder: (ctx2) {
                  final sexoOptions = ['Masculino', 'Femenino'];
                  final currentValue = sexoOptions.contains(_sexo) ? _sexo : null;
                  return DropdownButtonFormField<String>(
                    value: currentValue,
                    hint: const Text('Seleccionar'),
                    items: sexoOptions.map((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
                    onChanged: (v) {
                      _markTouched('sexo');
                      setState(() => _sexo = v);
                    },
                    validator: (v) {
                      if (!_shouldShowError('sexo')) return null;
                      return v == null ? 'Seleccione sexo' : null;
                    },
                    decoration: InputDecoration(labelText: 'Sexo *', prefixIcon: Icon(Icons.wc, color: borderColor.withOpacity(0.9)), isDense: true, prefixIconConstraints: BoxConstraints(minWidth: 36, minHeight: 36)),
                  );
                }),
              ],
            );
          } else {
            return Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _fechaCtrl,
                    readOnly: true,
                    onTap: () async {
                      _markTouched('fecha_nacimiento');
                      final now = DateTime.now();
                      final initial = _fechaNacimiento ?? DateTime(now.year - 18);
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: initial,
                        firstDate: DateTime(1900),
                        lastDate: now,
                        locale: const Locale('es', 'ES'),
                      );
                      if (picked != null) {
                        setState(() {
                          _fechaNacimiento = picked;
                          _fechaCtrl.text = DateFormat('dd/MM/yyyy').format(picked.toLocal());
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Fecha nacimiento *',
                      hintText: 'Seleccionar',
                      prefixIcon: Icon(Icons.calendar_today, color: borderColor.withOpacity(0.9)),
                      isDense: true,
                      prefixIconConstraints: BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                    validator: (_) {
                      if (!_shouldShowError('fecha_nacimiento')) return null;
                      return _fechaNacimiento == null ? 'Seleccione fecha' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Builder(builder: (ctx) {
                    final sexoOptions = ['Masculino', 'Femenino'];
                    final currentValue = sexoOptions.contains(_sexo) ? _sexo : null;
                    return DropdownButtonFormField<String>(
                      value: currentValue,
                      hint: const Text('Seleccionar'),
                      items: sexoOptions.map((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
                      onChanged: (v) {
                        _markTouched('sexo');
                        setState(() => _sexo = v);
                      },
                      validator: (v) {
                        if (!_shouldShowError('sexo')) return null;
                        return v == null ? 'Seleccione sexo' : null;
                      },
                      decoration: InputDecoration(labelText: 'Sexo *', prefixIcon: Icon(Icons.wc, color: borderColor.withOpacity(0.9)), isDense: true, prefixIconConstraints: BoxConstraints(minWidth: 36, minHeight: 36)),
                    );
                  }),
                ),
              ],
            );
          }
        }),
        const SizedBox(height: 12),

        // Teléfonos (datos personales - vertical)
        TextFormField(
          controller: _telefonoCtrl,
          onChanged: (_) => _markTouched('telefono'),
          decoration: InputDecoration(labelText: 'Teléfono *', prefixIcon: Icon(Icons.phone, color: borderColor.withOpacity(0.9))),
          validator: (v) {
            if (!_shouldShowError('telefono')) return null;
            return (v == null || v.trim().isEmpty) ? 'Ingrese teléfono' : null;
          },
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _telefonoApoderadoCtrl,
          onChanged: (_) => _markTouched('telefono_apoderado'),
          decoration: InputDecoration(labelText: 'Tel. apoderado (opcional)', prefixIcon: Icon(Icons.phone_android, color: borderColor.withOpacity(0.9))),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),

        // Dirección
        TextFormField(
          controller: _direccionCtrl,
          onChanged: (_) => _markTouched('direccion'),
          decoration: InputDecoration(labelText: 'Dirección (opcional)', prefixIcon: Icon(Icons.location_on, color: borderColor.withOpacity(0.9))),
        ),
        const SizedBox(height: 12),

        // Credenciales (sección separada)
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.midnightBlue.withOpacity(0.08) : AppColors.midnightBlue.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.vpn_key, size: 18),
                  const SizedBox(width: 8),
                  Text('Credenciales', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 10),
              // Username + Email (responsive: stack vertically on narrow widths)
              LayoutBuilder(builder: (ctx, constraints) {
                final narrow = constraints.maxWidth < 520;
                return Column(
                  children: [
                    if (narrow) ...[
                      TextFormField(
                        controller: _usernameCtrl,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.person_outline, color: borderColor.withOpacity(0.9)),
                          labelText: 'Nombre de usuario (opcional) - usado para iniciar sesión',
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 10),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _usernameCtrl,
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.person_outline, color: borderColor.withOpacity(0.9)),
                                labelText: 'Nombre de usuario (opcional)',
                              ),
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: SizedBox.shrink()),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Passwords (also responsive)
                    if (narrow) ...[
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscurePass,
                        onChanged: (_) => _markTouched('password'),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.lock_outline, color: borderColor.withOpacity(0.9)),
                          labelText: 'Contraseña *',
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, color: borderColor.withOpacity(0.6)),
                            onPressed: () => setState(() => _obscurePass = !_obscurePass),
                          ),
                        ),
                        validator: (v) {
                          if (!_shouldShowError('password')) return null;
                          return (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _confirmCtrl,
                        obscureText: _obscureConfirm,
                        onChanged: (_) => _markTouched('confirm'),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.lock, color: borderColor.withOpacity(0.9)),
                          labelText: 'Confirmar contraseña *',
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: borderColor.withOpacity(0.6)),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                        validator: (v) {
                          if (!_shouldShowError('confirm')) return null;
                          return v != _passCtrl.text ? 'No coincide' : null;
                        },
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _passCtrl,
                              obscureText: _obscurePass,
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.lock_outline, color: borderColor.withOpacity(0.9)),
                                labelText: 'Contraseña *',
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, color: borderColor.withOpacity(0.6)),
                                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                                ),
                              ),
                              onChanged: (_) => _markTouched('password'),
                              validator: (v) {
                                if (!_shouldShowError('password')) return null;
                                return (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _confirmCtrl,
                              obscureText: _obscureConfirm,
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.lock, color: borderColor.withOpacity(0.9)),
                                labelText: 'Confirmar contraseña *',
                                suffixIcon: IconButton(
                                  icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: borderColor.withOpacity(0.6)),
                                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                ),
                              ),
                              onChanged: (_) => _markTouched('confirm'),
                              validator: (v) {
                                if (!_shouldShowError('confirm')) return null;
                                return v != _passCtrl.text ? 'No coincide' : null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Notas (opcional)
        TextFormField(
          controller: _notasCtrl,
          decoration: InputDecoration(labelText: 'Notas (opcional)', prefixIcon: Icon(Icons.note, color: borderColor.withOpacity(0.9))),
          maxLines: 3,
        ),
        const SizedBox(height: 14),

        // Rol selector (propietario / inquilino)
        Text('Tipo de cuenta', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  _markTouched('rol');
                  setState(() {
                    _rol = 'propietario';
                    // Assumption: propietario role id is 1. Change if backend expects different values.
                    _rolId = 1;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _rol == 'propietario' ? buttonColor : borderColor.withOpacity(0.12), width: _rol == 'propietario' ? 2 : 1),
                    color: _rol == 'propietario' ? buttonColor.withOpacity(0.06) : Colors.transparent,
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.home_work, size: 28, color: _rol == 'propietario' ? buttonColor : borderColor.withOpacity(0.9)),
                      const SizedBox(height: 6),
                      Text('Propietario', style: TextStyle(color: _rol == 'propietario' ? buttonColor : borderColor.withOpacity(0.9))),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  _markTouched('rol');
                  setState(() {
                    _rol = 'inquilino';
                    // Assumption: inquilino role id is 2. Change if backend expects different values.
                    _rolId = 2;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _rol == 'inquilino' ? buttonColor : borderColor.withOpacity(0.12), width: _rol == 'inquilino' ? 2 : 1),
                    color: _rol == 'inquilino' ? buttonColor.withOpacity(0.06) : Colors.transparent,
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.person, size: 28, color: _rol == 'inquilino' ? buttonColor : borderColor.withOpacity(0.9)),
                      const SizedBox(height: 6),
                      Text('Inquilino', style: TextStyle(color: _rol == 'inquilino' ? buttonColor : borderColor.withOpacity(0.9))),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_shouldShowError('rol') && _rol == null) ...[
          const SizedBox(height: 8),
          Text('Seleccione un tipo de cuenta', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
        ],
        const SizedBox(height: 14),

        // Button
        SizedBox(
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: AppColors.alabaster,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _submit,
            child: const Text('Registrarse', style: TextStyle(fontSize: 18)),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('¿Ya tienes cuenta?', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(width: 6),
            Semantics(
              button: true,
              label: 'Iniciar sesión',
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: widget.onLogin,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Iniciar sesión', style: TextStyle(color: isDark ? AppColors.alabaster : AppColors.midnightBlue)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _submit() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      setState(() => _showErrors = true);
      // re-run validation after the frame so fields display errors immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _formKey.currentState?.validate();
      });
      return;
    }

    final data = <String, dynamic>{
      'nombre': _nameCtrl.text.trim(),
      'apellido': _apellidoCtrl.text.trim(),
      'username': _usernameCtrl.text.trim().isEmpty ? null : _usernameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'password': _passCtrl.text,
      'tipo_documento': _tipoDocumento,
      'dni': _dniCtrl.text.trim(),
      'fecha_nacimiento': _fechaNacimiento?.toIso8601String(),
      'telefono': _telefonoCtrl.text.trim(),
      'telefono_apoderado': _telefonoApoderadoCtrl.text.trim().isEmpty ? null : _telefonoApoderadoCtrl.text.trim(),
      'direccion': _direccionCtrl.text.trim().isEmpty ? null : _direccionCtrl.text.trim(),
      'notas': _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
      'sexo': _sexo,
      // server-side default fields
      'rol_id': _rolId,
      'email_verificado': null,
      'estado': 'activo',
    };

    // Ensure role selected (since it's not a FormField validator)
    if (_rolId == null) {
      setState(() => _showErrors = true);
      return;
    }

    widget.onRegister(data);
  }
}
