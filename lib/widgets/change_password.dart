import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'styled_card.dart';
import '../theme.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  // Password strength tracking
  bool _hasMinLength = false;
  bool _hasLetters = false;
  bool _hasNumbers = false;
  bool _hasSymbols = false;
  bool _passwordsMatch = false;
  double _passwordStrength = 0.0;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateCurrentPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresa tu contraseña actual';
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresa tu nueva contraseña';
    }
    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    if (value == _currentPasswordController.text) {
      return 'La nueva contraseña debe ser diferente a la actual';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirma tu nueva contraseña';
    }
    if (value != _newPasswordController.text) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  void _checkPasswordStrength(String password) {
    setState(() {
      // Check minimum length (6 characters)
      _hasMinLength = password.length >= 6;

      // Check for letters (both upper and lowercase)
      _hasLetters = RegExp(r'[a-zA-Z]').hasMatch(password);

      // Check for numbers
      _hasNumbers = RegExp(r'[0-9]').hasMatch(password);

      // Check for symbols
      _hasSymbols = RegExp(
        r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\/~`]',
      ).hasMatch(password);

      // Calculate strength (0.0 to 1.0)
      int criteriaCount = 0;
      if (_hasMinLength) criteriaCount++;
      if (_hasLetters) criteriaCount++;
      if (_hasNumbers) criteriaCount++;
      if (_hasSymbols) criteriaCount++;

      _passwordStrength = criteriaCount / 4.0;
    });
  }

  void _checkPasswordsMatch(String confirmPassword) {
    setState(() {
      _passwordsMatch =
          confirmPassword.isNotEmpty &&
          confirmPassword == _newPasswordController.text;
    });
  }

  Color _getStrengthColor() {
    if (_passwordStrength >= 0.75) {
      return Colors.green;
    } else if (_passwordStrength >= 0.5) {
      return Colors.orange;
    } else if (_passwordStrength > 0) {
      return Colors.red;
    }
    return Colors.grey;
  }

  String _getStrengthText() {
    if (_passwordStrength >= 0.75) {
      return 'Fuerte';
    } else if (_passwordStrength >= 0.5) {
      return 'Media';
    } else if (_passwordStrength > 0) {
      return 'Débil';
    }
    return '';
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Call backend API to change password
      await ApiService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (!mounted) return;

      // Success: clear form
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      // Reset password strength indicators
      setState(() {
        _hasMinLength = false;
        _hasLetters = false;
        _hasNumbers = false;
        _hasSymbols = false;
        _passwordsMatch = false;
        _passwordStrength = 0.0;
      });

      // Show success message
      _showMessage('Contraseña cambiada exitosamente');

      // Navigate back immediately after showing message
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      String errorMsg = e.message;

      // Provide user-friendly error messages
      if (e.statusCode == 401) {
        errorMsg = 'Contraseña actual incorrecta';
      } else if (e.statusCode == 400) {
        errorMsg = 'Datos inválidos. Verifica los campos';
      } else if (errorMsg.contains('Connection error')) {
        errorMsg = 'Error de conexión. Verifica tu internet';
      } else if (errorMsg.contains('timeout')) {
        errorMsg = 'Tiempo de espera agotado. Intenta de nuevo';
      }

      _showMessage(errorMsg, isError: true);
    } catch (e) {
      if (!mounted) return;
      // Don't show the raw error, just a generic message
      debugPrint('Error changing password: $e');
      _showMessage(
        'Error al cambiar la contraseña. Intenta de nuevo.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar contraseña'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info card
              StyledCard(
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: isDark ? AppColors.tan : AppColors.midnightBlue,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Por seguridad, necesitas ingresar tu contraseña actual para cambiarla.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Current password
              Text(
                'Contraseña actual',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrentPassword,
                validator: _validateCurrentPassword,
                decoration: InputDecoration(
                  hintText: 'Ingresa tu contraseña actual',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrentPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureCurrentPassword = !_obscureCurrentPassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.kBorderRadius),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // New password
              Text(
                'Nueva contraseña',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                validator: _validateNewPassword,
                decoration: InputDecoration(
                  hintText: 'Mínimo 6 caracteres',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureNewPassword = !_obscureNewPassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.kBorderRadius),
                  ),
                ),
                onChanged: (value) {
                  _checkPasswordStrength(value);
                  // Revalidate confirm password when new password changes
                  if (_confirmPasswordController.text.isNotEmpty) {
                    _checkPasswordsMatch(_confirmPasswordController.text);
                    _formKey.currentState?.validate();
                  }
                },
              ),
              const SizedBox(height: 12),

              // Password strength indicator
              if (_newPasswordController.text.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _passwordStrength,
                          backgroundColor: Colors.grey.shade300,
                          color: _getStrengthColor(),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _getStrengthText(),
                      style: TextStyle(
                        color: _getStrengthColor(),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Password requirements checklist
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRequirementItem(
                        'Al menos 6 caracteres',
                        _hasMinLength,
                      ),
                      const SizedBox(height: 6),
                      _buildRequirementItem('Contiene letras', _hasLetters),
                      const SizedBox(height: 6),
                      _buildRequirementItem('Contiene números', _hasNumbers),
                      const SizedBox(height: 6),
                      _buildRequirementItem(
                        'Contiene símbolos (!@#\$%...)',
                        _hasSymbols,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Confirm password
              Text(
                'Confirmar nueva contraseña',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                validator: _validateConfirmPassword,
                decoration: InputDecoration(
                  hintText: 'Repite tu nueva contraseña',
                  prefixIcon: Icon(
                    _passwordsMatch
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                    color: _passwordsMatch ? Colors.green : null,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.kBorderRadius),
                    borderSide: _passwordsMatch
                        ? const BorderSide(color: Colors.green, width: 2)
                        : const BorderSide(),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.kBorderRadius),
                    borderSide: _passwordsMatch
                        ? const BorderSide(color: Colors.green, width: 2)
                        : BorderSide(color: Colors.grey.shade400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.kBorderRadius),
                    borderSide: _passwordsMatch
                        ? const BorderSide(color: Colors.green, width: 2)
                        : BorderSide(
                            color: Theme.of(context).primaryColor,
                            width: 2,
                          ),
                  ),
                ),
                onChanged: (value) {
                  _checkPasswordsMatch(value);
                },
              ),

              // Match indicator
              if (_confirmPasswordController.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      _passwordsMatch ? Icons.check_circle : Icons.cancel,
                      color: _passwordsMatch ? Colors.green : Colors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _passwordsMatch
                          ? 'Las contraseñas coinciden'
                          : 'Las contraseñas no coinciden',
                      style: TextStyle(
                        color: _passwordsMatch ? Colors.green : Colors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleChangePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? AppColors.maroon
                        : AppColors.midnightBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.kBorderRadius,
                      ),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Cambiar contraseña',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Security tips
              StyledCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.security,
                          color: isDark
                              ? AppColors.tan
                              : AppColors.midnightBlue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Consejos de seguridad',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildSecurityTip('• Usa al menos 6 caracteres'),
                    _buildSecurityTip('• Combina letras, números y símbolos'),
                    _buildSecurityTip('• No uses información personal'),
                    _buildSecurityTip(
                      '• No reutilices contraseñas de otras cuentas',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequirementItem(String text, bool isMet) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isMet ? Colors.green : Colors.grey,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: isMet
                ? Colors.green
                : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.black87),
            fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white70
              : Colors.black87,
        ),
      ),
    );
  }
}
