import 'package:flutter/material.dart';
import 'styled_card.dart';
import '../theme.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'photo_cropper.dart';
import 'robust_image.dart';
import 'leading_icon.dart';
import '../presentation/providers/auth_provider.dart';
// cache persistence handled via AuthProvider

class ProfileEdit extends StatefulWidget {
  const ProfileEdit({super.key});

  @override
  State<ProfileEdit> createState() => _ProfileEditState();
}

class _ProfileEditState extends State<ProfileEdit> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _fechaNacimientoController = TextEditingController();
  final TextEditingController _fotoUrlController = TextEditingController();

  Map<String, dynamic> _original = {};
  bool _loading = false;
  bool _isPicking = false;
  Uint8List? _croppedBytes;
  String? _originalFotoValue;
  final int _maxImageDimension = 800;

  String? _pick(Map<String, dynamic>? src, List<String> keys) {
    if (src == null) return null;
    for (final k in keys) {
      final v = src[k];
      if (v == null) continue;
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v is int || v is double) return v.toString();
    }
    return null;
  }

  Uint8List? _bytesFromDataUri(String? uri) {
    if (uri == null) return null;
    final prefix = 'base64,';
    final idx = uri.indexOf(prefix);
    if (idx < 0) return null;
    try {
      final b64 = uri.substring(idx + prefix.length);
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    // populate from provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final profile = auth.profile ?? {};
      _original = Map<String, dynamic>.from(profile);

      _displayNameController.text = _pick(profile, ['displayName', 'nombre', 'user', 'username', 'email']) ?? '';
      _emailController.text = _pick(profile, ['email']) ?? '';
      _telefonoController.text = _pick(profile, ['telefono', 'phone', 'telefono_celular']) ?? '';
      _direccionController.text = _pick(profile, ['direccion', 'direccion_completa', 'address']) ?? '';
      _fechaNacimientoController.text = _pick(profile, ['fecha_nacimiento', 'fechaNacimiento', 'birth_date']) ?? '';
      _fotoUrlController.text = _pick(profile, ['foto_url', 'avatar', 'photo']) ?? '';
      // remember original foto value so we can revert later
      _originalFotoValue = _fotoUrlController.text.isNotEmpty ? _fotoUrlController.text : null;
      // If the stored foto is a data-uri, pre-fill _croppedBytes so preview
      // shows exactly how the profile photo will look while editing.
      try {
        final fromUri = _bytesFromDataUri(_fotoUrlController.text);
        if (fromUri != null) _croppedBytes = fromUri;
      } catch (_) {}


      setState(() {});
    });
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _fechaNacimientoController.dispose();
    _fotoUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickAndCrop() async {
    if (_isPicking) {
      debugPrint('[ProfileEdit] pick ignored, picker already active');
      _showMessage('Otra operación de selección está en curso', success: false);
      return;
    }
    setState(() => _isPicking = true);
    try {
      // Capture navigator/messenger/auth before async gaps to avoid
      // use_build_context_synchronously lint warnings.
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      // Open the pure-Dart cropper page to allow the user to position/zoom
      final result = await navigator.push<Uint8List?>(
        MaterialPageRoute(builder: (_) => PhotoCropperPage(imageBytes: bytes)),
      );
      if (result == null) return;
      if (!mounted) return;
      // resize if needed to avoid huge memory usage on Image.memory
      final resized = await _maybeResizeImage(result, _maxImageDimension);
      final dataUri = 'data:image/png;base64,${base64Encode(resized)}';
      setState(() {
        _croppedBytes = resized;
        // also reflect the data-uri in the foto url field so saving uses it
        _fotoUrlController.text = dataUri;
      });
      // Update provider locally so other parts of the app show the preview
      try {
        final mergedLocal = Map<String, dynamic>.from(_original);
        mergedLocal['foto_url'] = dataUri;
        debugPrint('[ProfileEdit] About to setLocalProfile, bytes=${result.length}');
        await auth.setLocalProfile(mergedLocal);
        debugPrint('[ProfileEdit] setLocalProfile completed');
        messenger.showSnackBar(SnackBar(content: Text('Vista previa actualizada (${result.length} bytes)'), backgroundColor: Colors.green[700]));
      } catch (e, st) {
        debugPrint('[ProfileEdit] setLocalProfile error: $e');
        debugPrint(st.toString());
        messenger.showSnackBar(SnackBar(content: Text('No se pudo actualizar la vista previa: ${e.toString()}'), backgroundColor: Colors.red[700]));
      }
    } catch (e) {
      debugPrint('[ProfileEdit] pickAndCrop error: $e');
      try {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(SnackBar(content: Text('Error al seleccionar/recortar imagen: ${e.toString()}'), backgroundColor: Colors.red[700]));
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  // Resize the image bytes if either dimension exceeds maxDimension.
  // Returns the original bytes if no resize needed.
  Future<Uint8List> _maybeResizeImage(Uint8List bytes, int maxDimension) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final width = img.width;
      final height = img.height;
      if (width <= maxDimension && height <= maxDimension) return bytes;
      final scale = maxDimension / (width > height ? width : height);
      final targetW = (width * scale).round();
      final targetH = (height * scale).round();
      final codec2 = await ui.instantiateImageCodec(bytes, targetWidth: targetW, targetHeight: targetH);
      final frame2 = await codec2.getNextFrame();
      final resizedImage = frame2.image;
      final byteData = await resizedImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return bytes;
      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('[ProfileEdit] resize failed: $e');
      return bytes;
    }
  }

  void _showMessage(String text, {bool success = true}) {
    if (!mounted) return;
    final color = success ? Colors.green[700] : Colors.red[700];
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: color));
  }

  Future<void> _onSave() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final Map<String, dynamic> updates = {};

    void maybeSet(String key, String value) {
      final orig = (_original[key] ?? _original[_mapAltKey(key)])?.toString() ?? '';
      final trimmed = value.trim();
      if (trimmed != orig) updates[key] = trimmed;
    }

    maybeSet('displayName', _displayNameController.text);
    maybeSet('email', _emailController.text);
    maybeSet('telefono', _telefonoController.text);
    maybeSet('direccion', _direccionController.text);
    maybeSet('fecha_nacimiento', _fechaNacimientoController.text);
    maybeSet('foto_url', _fotoUrlController.text);

    if (updates.isEmpty && _croppedBytes == null) {
      _showMessage('No hay cambios para guardar', success: false);
      return;
    }

    setState(() => _loading = true);
    try {
      // If there are no server updates but there is a local cropped image,
      // save the image locally into the profile cache and notify provider.
      if (updates.isEmpty && _croppedBytes != null) {
        final dataUri = 'data:image/png;base64,${base64Encode(_croppedBytes!)}';
        final mergedLocal = Map<String, dynamic>.from(_original);
        mergedLocal['foto_url'] = dataUri;
        // update provider locally and persist
        await auth.setLocalProfile(mergedLocal);
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text('Foto actualizada localmente'), backgroundColor: Colors.green[700]));
        navigator.pop(mergedLocal);
        return;
      }
      // Some backends expect the full resource on update. Try sending only
      // changed fields first; if server fails, fallback to merged full profile.
      Map<String, dynamic> payload = Map<String, dynamic>.from(updates);
      Map<String, dynamic> merged = Map<String, dynamic>.from(_original)..addAll(updates);

      // If user changed the photo locally, include it in the merged local
      // profile so we can persist it after a successful server update.
      String? localDataUri;
      if (_croppedBytes != null) {
        localDataUri = 'data:image/png;base64,${base64Encode(_croppedBytes!)}';
        merged['foto_url'] = localDataUri;
      }

      // Attempt update with minimal payload first. Do NOT fallback to sending
      // the full merged profile — some backends cannot safely merge collection
      // fields and will throw server-side exceptions (ConcurrentModification).
      try {
        final result = await auth.updateProfile(payload);
        // persist local photo if present
        if (localDataUri != null) {
          final mergedLocal = Map<String, dynamic>.from(result)..addAll({'foto_url': localDataUri});
          await auth.setLocalProfile(mergedLocal);
          if (!mounted) return;
          messenger.showSnackBar(SnackBar(content: Text('Perfil actualizado correctamente'), backgroundColor: Colors.green[700]));
          navigator.pop(mergedLocal);
          return;
        }
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text('Perfil actualizado correctamente'), backgroundColor: Colors.green[700]));
        navigator.pop(result);
        return;
      } catch (e) {
        // Surface the server error instead of retrying with a larger payload.
        debugPrint('[ProfileEdit] updateProfile failed: $e');
        if (mounted) messenger.showSnackBar(SnackBar(content: Text('Error al actualizar: ${e.toString()}'), backgroundColor: Colors.red[700]));
        return;
      }
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('Error al actualizar: ${e.toString()}'), backgroundColor: Colors.red[700]));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  // helper to map canonical key to common alternates used in profile
  String _mapAltKey(String key) {
    switch (key) {
      case 'displayName':
        return 'nombre';
      case 'telefono':
        return 'phone';
      case 'direccion':
        return 'address';
      case 'fecha_nacimiento':
        return 'fechaNacimiento';
      case 'foto_url':
        return 'avatar';
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar perfil'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _onSave,
            child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(0),
          children: [
            // Header with gradient and avatar
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF4A90E2), Color(0xFF6FB1FC)]),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppTheme.kBorderRadius)),
                ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 56,
                        backgroundColor: Colors.white,
                        child: ClipOval(
                          child: SizedBox(
                            width: 104,
                            height: 104,
                            child: _buildAvatarImage(),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Opacity(
                          opacity: _isPicking ? 0.6 : 1.0,
                          child: GestureDetector(
                            onTap: _isPicking ? null : _pickAndCrop,
                            child: _isPicking
                              ? const SizedBox(width: 40, height: 40, child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))))
                              : LeadingIcon(Icons.photo_camera, size: 40.0, backgroundColor: Colors.white),
                          ),
                        ),
                      ),
                      // Revert button (left-bottom)
                      if (_originalFotoValue != null)
                        Positioned(
                          left: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: _revertPhoto,
                            child: LeadingIcon(Icons.restore, size: 34.0, backgroundColor: Colors.white),
                          ),
                        )
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _displayNameController.text.isNotEmpty ? _displayNameController.text : 'Tu nombre',
                    style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _emailController.text.isNotEmpty ? _emailController.text : '',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: StyledCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _displayNameController,
                      decoration: const InputDecoration(labelText: 'Nombre para mostrar', prefixIcon: Icon(Icons.person)),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.email)),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _telefonoController,
                      decoration: const InputDecoration(labelText: 'Teléfono', prefixIcon: Icon(Icons.phone)),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _direccionController,
                      decoration: const InputDecoration(labelText: 'Dirección', prefixIcon: Icon(Icons.location_on)),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fechaNacimientoController,
                      decoration: const InputDecoration(labelText: 'Fecha de nacimiento (YYYY-MM-DD)', prefixIcon: Icon(Icons.calendar_today)),
                      keyboardType: TextInputType.datetime,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fotoUrlController,
                      decoration: const InputDecoration(labelText: 'URL de la foto', prefixIcon: Icon(Icons.link)),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _onSave,
                        icon: const Icon(Icons.save),
                        label: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('Guardar cambios')),
                        style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Future<void> _revertPhoto() async {
    if (!mounted) return;
    final orig = _originalFotoValue;
    if (orig == null || orig.isEmpty) {
      _showMessage('No hay imagen original para revertir', success: false);
      return;
    }
    // If original is data-uri, restore bytes; if it's a remote URL, clear bytes and set URL
    final bytes = _bytesFromDataUri(orig);
    setState(() {
      if (bytes != null) {
        _croppedBytes = bytes;
      } else {
        _croppedBytes = null;
      }
      _fotoUrlController.text = orig;
    });
    // Update provider locally to reflect the reverted image immediately
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final mergedLocal = Map<String, dynamic>.from(_original);
      if (orig.isNotEmpty) mergedLocal['foto_url'] = orig;
      await auth.setLocalProfile(mergedLocal);
    } catch (_) {}
    _showMessage('Foto revertida');
  }

  Widget _buildAvatarImage() {
    // priority: cropped bytes > data-uri in foto url > placeholder
    if (_croppedBytes != null) {
      return Image.memory(
        _croppedBytes!,
        width: 104,
        height: 104,
        fit: BoxFit.cover,
        errorBuilder: (ctx, error, stack) {
          debugPrint('[ProfileEdit] Image.memory error: $error');
          return Container(color: Theme.of(context).cardColor, child: Center(child: Icon(Icons.person, size: 48, color: Theme.of(context).iconTheme.color)));
        },
      );
    }
    final txt = _fotoUrlController.text.trim();
    final fromUri = _bytesFromDataUri(txt);
    if (fromUri != null) return Image.memory(fromUri, width: 104, height: 104, fit: BoxFit.cover, errorBuilder: (ctx, error, stack) {
      debugPrint('[ProfileEdit] Image.memory(fromUri) error: $error');
      return Container(color: Theme.of(context).cardColor, child: Center(child: Icon(Icons.person, size: 48, color: Theme.of(context).iconTheme.color)));
    });
    // If it's a remote URL, show network image preview so the user sees
    // how the foto will appear before editing.
    if (txt.startsWith('http://') || txt.startsWith('https://')) {
      return RobustImage(
        source: txt,
        width: 104,
        height: 104,
        fit: BoxFit.cover,
        borderRadius: BorderRadius.zero,
      );
    }
    // fallback placeholder
    return Container(
      color: Theme.of(context).cardColor,
      child: Center(child: Icon(Icons.person, size: 48, color: Theme.of(context).iconTheme.color)),
    );
  }
}

