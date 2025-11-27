import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../config/api.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../presentation/providers/auth_provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
// Avoid google_fonts runtime AssetManifest lookups; use bundled Poppins.
// import removed: cached_network_image no longer used directly in gallery
import '../../widgets/robust_image.dart';
import 'package:reorderables/reorderables.dart';
import '../../services/api_service.dart' as api_service;

// Local style constants to match the design screenshots
const _kTitleColor = Color(0xFF0B3A36); // dark teal for headings
const _kBodyColor = Color(0xFF234343); // subtitle/body darker teal
const _kMaroon = Color(0xFF7F0303); // action / accent maroon
const _kStatIcon = Color(0xFF0B6B63); // stat card icon color

class Residence {
  final int id;
  final String nombre;
  final Map<String, dynamic> ubicacion;
  final List<String> imagenes;
  final String descripcion;
  final String serviciosCsv;
  final String telefonoContacto;
  final int habitacionesTotales;
  final int habitacionesOcupadas;
  final num precio;
  final String propietarioNombre;
  final String propietarioApellido;
  final String tipo;
  final String reglamentoUrl;
  final String emailContacto;

  Residence({
    required this.id,
    required this.nombre,
    required this.ubicacion,
    required this.imagenes,
    required this.descripcion,
    required this.serviciosCsv,
    required this.telefonoContacto,
    required this.habitacionesTotales,
    required this.habitacionesOcupadas,
    required this.precio,
    required this.propietarioNombre,
    required this.propietarioApellido,
    this.tipo = '',
    this.reglamentoUrl = '',
    this.emailContacto = '',
  });

  factory Residence.fromJson(Map<String, dynamic> json) {
    final map = json['data'] is Map ? json['data'] as Map<String, dynamic> : json;
    return Residence(
      id: (map['id'] is int) ? map['id'] as int : int.tryParse('${map['id']}') ?? 0,
      nombre: (map['nombre'] ?? map['title'] ?? map['name'] ?? '').toString(),
      ubicacion: Map<String, dynamic>.from(map['ubicacion'] ?? map['location'] ?? {}),
      imagenes: (() {
        List<String> out = [];
        dynamic raw;
        if (map['imagenes'] != null) raw = map['imagenes'];
        else if (map['images'] != null) raw = map['images'];
        else if (map['imagen'] != null) raw = map['imagen'];
        else if (map['image'] != null) raw = map['image'];
        if (raw is List) {
          for (final e in raw) {
            if (e == null) continue;
            if (e is String) {
              final s = e.trim();
              if (s.isNotEmpty) out.add(s);
              continue;
            }
            if (e is Map) {
              final candidates = ['url', 'secure_url', 'src', 'path', 'imagen', 'image'];
              String? found;
              for (final k in candidates) {
                if (e.containsKey(k) && e[k] != null) {
                  final v = e[k];
                  if (v is String && v.trim().isNotEmpty) {
                    found = v.trim();
                    break;
                  }
                }
              }
              if (found != null) out.add(found);
              continue;
            }
            final s = e.toString().trim();
            if (s.isNotEmpty) out.add(s);
          }
        } else if (raw is String) {
          final s = raw.trim();
          if (s.isNotEmpty) out.add(s);
        } else if (raw is Map) {
          final candidates = ['url', 'secure_url', 'src', 'path', 'imagen', 'image'];
          for (final k in candidates) {
            if (raw.containsKey(k) && raw[k] != null && raw[k] is String && (raw[k] as String).trim().isNotEmpty) {
              out.add((raw[k] as String).trim());
              break;
            }
          }
        }
        var result = out.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
        if (result.isEmpty) {
          void _search(dynamic node) {
            if (node == null) return;
            if (node is String) {
              final s = node.trim();
              if (s.isNotEmpty && (s.startsWith('http://') || s.startsWith('https://') || s.startsWith('data:image/'))) {
                result.add(s);
              }
              return;
            }
            if (node is Map) {
              for (final v in node.values) {
                _search(v);
                if (result.isNotEmpty) return;
              }
              return;
            }
            if (node is List) {
              for (final e in node) {
                _search(e);
                if (result.isNotEmpty) return;
              }
            }
          }
          _search(map);
        }
        return result;
      })(),
      descripcion: (map['descripcion'] ?? map['description'] ?? '').toString(),
      serviciosCsv: (map['servicios'] ?? map['services'] ?? []).toString(),
      telefonoContacto: (map['telefonoContacto'] ?? map['phone'] ?? '').toString(),
      habitacionesTotales: ((map['habitacionesTotales'] ?? map['roomsTotal'] ?? 0) is int) ? (map['habitacionesTotales'] ?? map['roomsTotal'] ?? 0) as int : int.tryParse('${map['habitacionesTotales'] ?? map['roomsTotal'] ?? 0}') ?? 0,
      habitacionesOcupadas: ((map['habitacionesOcupadas'] ?? map['roomsOccupied'] ?? 0) is int) ? (map['habitacionesOcupadas'] ?? map['roomsOccupied'] ?? 0) as int : int.tryParse('${map['habitacionesOcupadas'] ?? map['roomsOccupied'] ?? 0}') ?? 0,
      precio: map['precio'] ?? map['price'] ?? map['valor'] ?? 0,
      tipo: (map['tipo'] ?? map['type'] ?? '').toString(),
      reglamentoUrl: (map['reglamentoUrl'] ?? map['reglamento'] ?? '').toString(),
      emailContacto: (map['emailContacto'] ?? map['email'] ?? '').toString(),
      propietarioNombre: (map['propietarioNombre'] is String && map['propietarioNombre'] != null)
        ? map['propietarioNombre'] as String
        : (map['propietarioNombre']?.toString() ?? ''),
      propietarioApellido: (map['propietarioApellido'] is String && map['propietarioApellido'] != null)
        ? map['propietarioApellido'] as String
        : (map['propietarioApellido']?.toString() ?? ''),
    );
  }
}

class _ParsedService {
  final String title;
  final String? subtitle;
  _ParsedService({required this.title, this.subtitle});
}

class ResidenceDetailPage extends StatefulWidget {
  final int residenceId;

  const ResidenceDetailPage({Key? key, required this.residenceId}) : super(key: key);

  @override
  State<ResidenceDetailPage> createState() => _ResidenceDetailPageState();
}

class _ResidenceDetailPageState extends State<ResidenceDetailPage> {

    void _onManageImagesPressed(Residence residence) {
      // Mantener la lista de imágenes fuera del StatefulBuilder para que persista
      List<String> images = List<String>.from(residence.imagenes);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (context) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.8,
            minChildSize: 0.3,
            maxChildSize: 0.95,
            builder: (ctx, scrollController) {
              return StatefulBuilder(
                builder: (ctx2, setState2) {
                  

                  bool _savingImages = false;
                  bool _uploading = false;

                  Future<void> _uploadImage(ImageSource source) async {
                    setState2(() => _uploading = true);
                    try {
                      final XFile? picked = await ImagePicker().pickImage(source: source);
                      if (picked == null) {
                        setState2(() => _uploading = false);
                        return;
                      }
                      final file = File(picked.path);
                      final uri = Uri.parse('${baseUrl}/api/files/residencia/${residence.id}/imagen');
                      final token = api_service.ApiService.authToken;

                      final req = http.MultipartRequest('POST', uri);
                      req.headers['Authorization'] = 'Bearer $token';
                      req.fields['orden'] = (images.length + 1).toString();
                      req.files.add(await http.MultipartFile.fromPath('file', file.path, filename: path.basename(file.path)));

                      final streamed = await req.send();
                      final res = await http.Response.fromStream(streamed);
                      if (res.statusCode >= 200 && res.statusCode < 300) {
                        try {
                          final Map<String, dynamic> data = jsonDecode(res.body);
                          String? found;
                          const candidates = ['url', 'secure_url', 'src', 'path', 'imagen', 'image'];
                          void _search(dynamic node) {
                            if (node == null) return;
                            if (node is String) {
                              final s = node.trim();
                              if (s.startsWith('http://') || s.startsWith('https://') || s.startsWith('data:image/')) {
                                found = s;
                                return;
                              }
                              return;
                            }
                            if (node is Map) {
                              for (final k in candidates) {
                                if (node.containsKey(k) && node[k] is String && (node[k] as String).trim().isNotEmpty) {
                                  found = (node[k] as String).trim();
                                  return;
                                }
                              }
                              for (final v in node.values) {
                                if (found != null) return;
                                _search(v);
                              }
                              return;
                            }
                            if (node is List) {
                              for (final e in node) {
                                if (found != null) return;
                                _search(e);
                              }
                            }
                          }
                          _search(data);
                          if (found != null) {
                            setState2(() => images.add(found!));
                          }
                        } catch (_) {}

                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Imagen subida')));
                        try {
                          await _fetchDetail();
                        } catch (_) {}
                      } else {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al subir imagen: ${res.statusCode}')));
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al subir imagen')));
                    } finally {
                      setState2(() => _uploading = false);
                    }
                  }

                  Future<void> _chooseUploadSource() async {
                    final choice = await showModalBottomSheet<String?>(context: ctx2, builder: (ctx3) {
                      return SafeArea(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          ListTile(leading: const Icon(Icons.photo_library), title: const Text('Galería'), onTap: () => Navigator.of(ctx3).pop('gallery')),
                          ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Cámara'), onTap: () => Navigator.of(ctx3).pop('camera')),
                          ListTile(leading: const Icon(Icons.close), title: const Text('Cancelar'), onTap: () => Navigator.of(ctx3).pop(null)),
                        ]),
                      );
                    });
                    if (choice == 'gallery') await _uploadImage(ImageSource.gallery);
                    else if (choice == 'camera') await _uploadImage(ImageSource.camera);
                  }

                  Future<bool> _saveImages(List<String> newImages) async {
                    final uri = Uri.parse('${baseUrl}/api/residencias/${residence.id}/imagenes');
                    // El token se gestiona globalmente en ApiService
                    final token = api_service.ApiService.authToken;
                    try {
                      final res = await http.put(
                        uri,
                        headers: {
                          'Authorization': 'Bearer $token',
                          'Content-Type': 'application/json',
                        },
                        body: jsonEncode({'imagenes': newImages}),
                      );
                      if (res.statusCode >= 200 && res.statusCode < 300) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Imágenes guardadas')));
                        }
                        return true;
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar imágenes: ${res.statusCode}')));
                        }
                        return false;
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error de red al guardar imágenes')));
                      }
                      return false;
                    }
                  }

                  void _onReorder(int oldIndex, int newIndex) {
                    setState2(() {
                      final img = images.removeAt(oldIndex);
                      images.insert(newIndex, img);
                    });
                  }

                  void _onDelete(int i) {
                    setState2(() {
                      images.removeAt(i);
                    });
                  }

                  return Padding(
                    padding: EdgeInsets.only(bottom: MediaQuery.of(ctx2).viewInsets.bottom),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Imágenes de la residencia', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18)),
                              IconButton(
                                icon: _uploading ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _kMaroon)) : const Icon(Icons.add_a_photo, color: _kMaroon),
                                onPressed: _uploading ? null : () => _chooseUploadSource(),
                                tooltip: 'Subir imagen',
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: images.isEmpty
                              ? const Center(child: Text('No hay imágenes'))
                                : AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 350),
                                  switchInCurve: Curves.easeOut,
                                  switchOutCurve: Curves.easeIn,
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: SingleChildScrollView(
                                      key: ValueKey(images.join(',')),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      child: ReorderableWrap(
                                        spacing: 14,
                                        runSpacing: 14,
                                        minMainAxisCount: 2,
                                        maxMainAxisCount: 2,
                                        needsLongPressDraggable: false,
                                        alignment: WrapAlignment.start,
                                        runAlignment: WrapAlignment.start,
                                        onReorder: _onReorder,
                                        children: List<Widget>.generate(images.length, (i) {
                                          final url = images[i];
                                          return AnimatedContainer(
                                            key: ValueKey(url),
                                            duration: const Duration(milliseconds: 300),
                                            curve: Curves.easeInOut,
                                            width: MediaQuery.of(context).size.width * 0.4,
                                            height: MediaQuery.of(context).size.width * 0.4 * 1.1,
                                            child: Stack(
                                              children: [
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(16),
                                                  child: RobustImage(
                                                    source: url,
                                                    width: double.infinity,
                                                    height: double.infinity,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                                Positioned(
                                                  top: 8,
                                                  left: 8,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black.withOpacity(0.55),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      '#${i + 1}',
                                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Poppins', fontSize: 13),
                                                    ),
                                                  ),
                                                ),
                                                Positioned(
                                                  right: 6,
                                                  top: 6,
                                                  child: _imageActionButton(
                                                    icon: Icons.delete_outline,
                                                    color: Colors.red,
                                                    onTap: () => _onDelete(i),
                                                    tooltip: 'Eliminar',
                                                  ),
                                                ),
                                                Positioned(
                                                  bottom: 8,
                                                  right: 8,
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withOpacity(0.7),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    padding: const EdgeInsets.all(4),
                                                    child: const Icon(Icons.drag_handle, size: 20, color: Colors.black54),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Builder(builder: (ctxBtn) {
                                final Widget saveIcon = _savingImages ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save);
                                final Widget saveLabel = _savingImages ? Text('Guardando...', style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)) : const Text('Guardar cambios', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600));
                                return ElevatedButton.icon(
                                  icon: saveIcon,
                                  label: saveLabel,
                                  style: ElevatedButton.styleFrom(backgroundColor: _kMaroon),
                                  onPressed: _savingImages ? null : () async {
                                      setState2(() => _savingImages = true);
                                      final ok = await _saveImages(images);
                                      if (ok) {
                                        try {
                                          await _fetchDetail();
                                        } catch (_) {}
                                      }
                                      // Turn off loader and close modal if successful
                                      setState2(() => _savingImages = false);
                                      if (ok) Navigator.of(ctx2).pop();
                                  },
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      );
    }

    // NOTA: necesitas agregar el paquete reorderables en pubspec.yaml:
    // reorderables: ^0.6.0
    // import 'package:reorderables/reorderables.dart';

    Widget _imageActionButton({required IconData icon, required VoidCallback onTap, String? tooltip, Color? color}) {
      return Material(
        color: Colors.white.withOpacity(0.85),
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: Icon(icon, size: 18, color: color ?? Colors.black87),
          ),
        ),
      );
    }
  final PageController _pageController = PageController();
  int _page = 0;

  String _initials(String name) {
    final parts = name.split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'P';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _residenceDetail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final data = await auth.getResidenciaById(widget.residenceId);
      setState(() {
        _residenceDetail = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _onEditPressed(Residence residence) async {
    // Open edit form and wait for result
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditResidenceForm(residence: residence),
    );
    // If edit was successful, refresh detail
    if (result == true) {
      await _fetchDetail();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Residencia actualizada')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(child: Text('Error: $_error', style: const TextStyle(fontSize: 18))),
      );
    }
    final r = _residenceDetail;
    if (r == null || r.isEmpty) {
      return Scaffold(
        body: Center(child: Text('Residencia no encontrada', style: const TextStyle(fontSize: 18))),
      );
    }
    final residence = Residence.fromJson(r);
    // ...existing code to build detail UI below...
    final effectiveImages = <String>[]..addAll(residence.imagenes);
    if (effectiveImages.isEmpty) {
      void _searchNode(dynamic node) {
        if (node == null) return;
        if (node is String) {
          final s = node.trim();
          if (s.isNotEmpty && (s.startsWith('http://') || s.startsWith('https://') || s.startsWith('data:image/'))) {
            effectiveImages.add(s);
          }
          return;
        }
        if (node is Map) {
          for (final v in node.values) {
            _searchNode(v);
            if (effectiveImages.isNotEmpty) return;
          }
          return;
        }
        if (node is List) {
          for (final e in node) {
            _searchNode(e);
            if (effectiveImages.isNotEmpty) return;
          }
        }
      }
      _searchNode(residence.ubicacion);
      if (effectiveImages.isEmpty) _searchNode(residence.descripcion);
      if (effectiveImages.isEmpty) _searchNode(residence.nombre);
    }
    final displayedImages = residence.imagenes;
    final services = residence.serviciosCsv.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF6F0E9),
      body: SafeArea(
        bottom: true,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              automaticallyImplyLeading: false,
              backgroundColor: Colors.transparent,
              expandedHeight: 320,
              flexibleSpace: FlexibleSpaceBar(
                background: SizedBox(
                  height: 320,
                  child: Stack(
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        itemCount: displayedImages.isNotEmpty ? displayedImages.length : 1,
                        onPageChanged: (i) => setState(() => _page = i),
                        itemBuilder: (c, i) {
                          final url = displayedImages.isNotEmpty ? displayedImages[i] : '';
                          if (kDebugMode) debugPrint('ResidenceDetail: building page $i for url="$url"');
                          return RobustImage(
                            source: url,
                            fit: BoxFit.cover,
                            height: 320,
                          );
                        },
                      ),
                      Positioned(left: 12, top: 12, child: _circleIconButton(icon: Icons.arrow_back, onTap: () => Navigator.of(context).pop())),
                      Positioned(right: 12, top: 12, child: Row(children: [
                        _circleIconButton(icon: Icons.favorite_border, onTap: () {}),
                        const SizedBox(width: 8),
                        _circleIconButton(icon: Icons.share, onTap: () {}),
                        const SizedBox(width: 8),
                        _circleIconButton(icon: Icons.photo_library, onTap: () => _onManageImagesPressed(residence)),
                        const SizedBox(width: 8),
                        _circleIconButton(icon: Icons.edit, onTap: () => _onEditPressed(residence)),
                        const SizedBox(width: 8),
                        _circleIconButton(icon: Icons.copy, onTap: () => _onCopyPressed(residence)),
                      ])),
                      Positioned(bottom: 12, left: 0, right: 0, child: Center(child: _buildIndicator(residence.imagenes.length))),
                    ],
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate([
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(residence.nombre, style: const TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w800, color: _kTitleColor)),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 6),
                      Text('4.5', style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 13, color: _kTitleColor)),
                      const SizedBox(width: 8),
                      Text('(23 reviews)', style: const TextStyle(fontFamily: 'Poppins', color: Colors.black54, fontSize: 12)),
                      const SizedBox(width: 12),
                      const Icon(Icons.location_on, size: 14, color: Colors.black54),
                      const SizedBox(width: 4),
                      Expanded(child: Text(residence.ubicacion['direccion']?.toString() ?? '', style: const TextStyle(fontFamily: 'Poppins', color: Colors.black54, fontSize: 13))),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _statCard(icon: Icons.bed_outlined, value: '${residence.habitacionesTotales}', label: 'Habitaciones')),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard(icon: Icons.person_outline, value: '${(residence.habitacionesTotales - residence.habitacionesOcupadas)}', label: 'Disponibles')),
                      const SizedBox(width: 12),
                      Expanded(child: _statCardOccupancy(occupancy: residence.habitacionesTotales == 0 ? 0 : ((residence.habitacionesOcupadas / residence.habitacionesTotales) * 100).round())),
                    ]),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Descripción', style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 18, color: _kTitleColor)),
                        const SizedBox(height: 10),
                        Text(
                          residence.descripcion,
                          textAlign: TextAlign.justify,
                          textWidthBasis: TextWidthBasis.parent,
                          style: const TextStyle(fontFamily: 'Poppins', height: 1.5, color: _kBodyColor, fontSize: 14),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    _sectionCard(title: 'Servicios', child: _servicesGrid(services)),
                    const SizedBox(height: 12),
                    _sectionCard(
                      title: 'Contacto',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: _kMaroon,
                                child: Text(
                                  _initials((residence.propietarioNombre + ' ' + residence.propietarioApellido).trim()),
                                  style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(
                                  ((residence.propietarioNombre + ' ' + residence.propietarioApellido).trim().isNotEmpty)
                                    ? (residence.propietarioNombre + ' ' + residence.propietarioApellido).trim()
                                    : residence.nombre,
                                  style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 16, color: _kTitleColor),
                                ),
                                const SizedBox(height: 2),
                                const Text('Propietario', style: TextStyle(fontFamily: 'Poppins', color: Colors.black54, fontSize: 12)),
                              ])
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: ElevatedButton.icon(onPressed: residence.telefonoContacto.isNotEmpty ? () => _call(residence.telefonoContacto) : null, icon: const Icon(Icons.call), label: const Text('Llamar', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 14)), style: ElevatedButton.styleFrom(backgroundColor: _kMaroon))),
                              const SizedBox(width: 12),
                              Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.email), label: const Text('Email', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 14)), style: OutlinedButton.styleFrom(backgroundColor: const Color(0xFFF7ECEC), foregroundColor: _kMaroon))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                  ]),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // Image handling is delegated to `lib/widgets/robust_image.dart` (RobustImage)

  Widget _circleIconButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(8.0), child: Icon(icon, size: 20, color: Colors.black87)),
      ),
    );
  }

  Widget _buildIndicator(int count) {
    if (count <= 1) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: List.generate(count, (i) => Container(margin: const EdgeInsets.symmetric(horizontal: 4), width: _page == i ? 28 : 8, height: 8, decoration: BoxDecoration(color: Colors.white.withOpacity(_page == i ? 0.95 : 0.6), borderRadius: BorderRadius.circular(8)))));
  }

  Widget _statCard({required IconData icon, required String value, required String label}) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: _kStatIcon),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 20, color: _kTitleColor)),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontFamily: 'Poppins', color: Colors.black54, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _statCardOccupancy({required int occupancy}) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(value: occupancy / 100, color: const Color(0xFFB33A3A), backgroundColor: const Color(0xFFEFEFEF)),
              Text('$occupancy%', style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 12, color: _kMaroon)),
            ]),
          ),
          const SizedBox(height: 8),
          const SizedBox(height: 6),
          const Text('Ocupación', style: TextStyle(fontFamily: 'Poppins', color: Colors.black54, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: Padding(padding: const EdgeInsets.all(14.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text(title, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 16, color: _kTitleColor)), const SizedBox(height: 10), child])),
    );
  }

  Widget _servicesGrid(List<String> services) {
    if (services.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, constraints) {
      // calculate two columns with spacing similar to design
      final gap = 12.0;
      final columns = 2;
      final itemWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: 12,
        children: services.map((s) => _serviceItem(s, width: itemWidth)).toList(),
      );
    });
  }

  Widget _serviceItem(String label, {double? width}) {
    final parsed = _parseReceptionIfNeeded(label);
    final icon = _serviceIcon(label);
    final child = Row(children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: const Color(0xFFE6F6F6), borderRadius: BorderRadius.circular(12)),
        child: Center(child: Icon(icon, color: const Color(0xFF3AA6A6), size: 20)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(parsed.title, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 14, color: _kTitleColor)),
          if (parsed.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(parsed.subtitle!, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.black54)),
          ]
        ]),
      ),
    ]);

    if (width != null) return SizedBox(width: width, child: child);
    return child;
  }

  // Map known service labels to Material icons.
  IconData _serviceIcon(String label) {
    final l = label.toLowerCase();
    if (l.contains('wifi')) return Icons.wifi;
    if (l.contains('luz') || l.contains('electricidad')) return Icons.flash_on;
    if (l.contains('agua')) return Icons.water_drop;
    if (l.contains('aire') || l.contains('acondicionado')) return Icons.ac_unit;
    if (l.contains('estacion') || l.contains('parking') || l.contains('parking')) return Icons.local_parking;
    if (l.contains('segurid')) return Icons.shield;
    if (l.contains('lavadora') || l.contains('lavado')) return Icons.local_laundry_service;
    if (l.contains('comedor') || l.contains('comida') || l.contains('Pensión')) return Icons.restaurant;
    if (l.contains('limpieza') || l.contains('limpieza')) return Icons.cleaning_services;
    if (l.contains('sala') && l.contains('estudio')) return Icons.menu_book;
    if (l.contains('horario') || l.contains('recepción') || l.contains('recepcion')) return Icons.schedule;
    // default
    return Icons.check_circle_outline;
  }

  // Special parsing for reception hours. Returns a title and optional subtitle.
  _ParsedService _parseReceptionIfNeeded(String label) {
    final l = label.trim();
    final low = l.toLowerCase();
    if (low.contains('horario') || low.contains('recep') || low.contains('recepción') || low.contains('recepcion')) {
      // try to extract common time patterns like '08:00-22:00' or '8:00 AM - 10:00 PM' or '24/7'
      final r24 = RegExp(r'24\s*[/]?\s*7');
      if (r24.hasMatch(low)) return _ParsedService(title: 'Horario de recepción', subtitle: '24/7');

      final timeRange = RegExp(r'(\d{1,2}:?\d{0,2})(?:\s*(?:am|pm))?\s*[-–to]{1,3}\s*(\d{1,2}:?\d{0,2})(?:\s*(?:am|pm))?', caseSensitive: false);
      final m = timeRange.firstMatch(l);
      if (m != null) {
        final a = _normalizeTime(m.group(1)!);
        final b = _normalizeTime(m.group(2)!);
        return _ParsedService(title: 'Horario de recepción', subtitle: '$a – $b');
      }

      // single time like 'Cerrado a las 22:00' or 'A partir de 09:00'
      final timeSingle = RegExp(r'(?:(?:a las|a partir de|desde)\s*)?(\d{1,2}:?\d{0,2})', caseSensitive: false);
      final m2 = timeSingle.firstMatch(l);
      if (m2 != null) {
        final a = _normalizeTime(m2.group(1)!);
        return _ParsedService(title: 'Horario de recepción', subtitle: a);
      }

      // fallback: show original label trimmed
      return _ParsedService(title: 'Horario de recepción', subtitle: low.replaceFirst(RegExp(r'horario\s*[:\-]?'), '').trim());
    }

    return _ParsedService(title: label, subtitle: null);
  }

  String _normalizeTime(String raw) {
    var s = raw.replaceAll(' ', '');
    if (!s.contains(':')) {
      // treat as hour like '8' -> '08:00'
      final num = int.tryParse(s) ?? 0;
      return '${num.toString().padLeft(2, '0')}:00';
    }
    final parts = s.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
  


  void _onCopyPressed(Residence residence) {
    final text = 'Residencia: ${residence.nombre}\nPropietario: ${residence.propietarioNombre} ${residence.propietarioApellido}\nTeléfono: ${residence.telefonoContacto}';
    debugPrint('Copiado al portapapeles: $text');
    // TODO: Implementar Clipboard.setData
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Datos copiados al portapapeles')),
    );
  }
}

// Formulario de edición base (estructura Clean Architecture: presentation)
class EditResidenceForm extends StatefulWidget {
  final Residence residence;
  final ScrollController? scrollController;
  const EditResidenceForm({Key? key, required this.residence, this.scrollController}) : super(key: key);

  @override
  State<EditResidenceForm> createState() => _EditResidenceFormState();
}

class _EditResidenceFormState extends State<EditResidenceForm> {
  late TextEditingController nombreController;
  late TextEditingController tipoController;
  late TextEditingController reglamentoController;
  late TextEditingController descripcionController;
  late TextEditingController telefonoController;
  late TextEditingController emailController;
  Set<String> serviciosSeleccionados = {};

  final List<String> tiposResidencia = ['Para hombres', 'Para mujeres', 'Mixto'];
  final Map<String, IconData> _tipoIcons = {
    'Para hombres': Icons.male,
    'Para mujeres': Icons.female,
    'Mixto': Icons.groups,
  };
  final List<String> servicios = [
  'Wifi', 'Lavandería', 'Pensión', 'Limpieza', 'Parking', 'Sala de estudio', 'Seguridad', 'Horario de recepción'
  ];
    final Map<String, IconData> servicioIcons = {
    'Wifi': Icons.wifi,
    'Lavandería': Icons.local_laundry_service,
    'Pensión': Icons.restaurant,
    'Limpieza': Icons.cleaning_services,
    'Parking': Icons.local_parking,
    'Sala de estudio': Icons.menu_book,
    'Seguridad': Icons.security,
    'Horario de recepción': Icons.schedule,
  };

  @override
  void initState() {
    super.initState();
    final r = widget.residence;
    nombreController = TextEditingController(text: r.nombre);
    // Map API `tipo` values (e.g. 'mixto', 'hombres', 'mujeres') to UI labels
    String mapTipo(String api) {
      final low = api.toLowerCase();
      if (low.contains('muj') || low.contains('female') || low.contains('mujeres')) return 'Para mujeres';
      if (low.contains('homb') || low.contains('male') || low.contains('hombres')) return 'Para hombres';
      if (low.contains('mix') || low.contains('mixto')) return 'Mixto';
      return '';
    }
    final mapped = mapTipo(r.tipo);
    tipoController = TextEditingController(text: mapped.isNotEmpty ? mapped : 'Mixto');
    reglamentoController = TextEditingController(text: r.reglamentoUrl); // Si tienes reglamentoUrl, pon aquí el valor
    descripcionController = TextEditingController(text: r.descripcion);
    telefonoController = TextEditingController(text: r.telefonoContacto);
    emailController = TextEditingController(text: r.emailContacto); // Si tienes emailContacto, pon aquí el valor
    // Parse serviciosCsv (puede venir como string separado por comas)
    serviciosSeleccionados = r.serviciosCsv.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    // Manage scroll controller and fade visibility
    if (widget.scrollController != null) {
      _scrollController = widget.scrollController!;
      _ownsScrollController = false;
    } else {
      _scrollController = ScrollController();
      _ownsScrollController = true;
    }
    _showHeaderFade = (_scrollController.hasClients && _scrollController.offset > 6);
    _scrollController.addListener(_onScrollChanged);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollChanged);
    if (_ownsScrollController) _scrollController.dispose();
    nombreController.dispose();
    tipoController.dispose();
    reglamentoController.dispose();
    descripcionController.dispose();
    telefonoController.dispose();
    emailController.dispose();
    super.dispose();
  }

  late ScrollController _scrollController;
  bool _ownsScrollController = false;
  bool _showHeaderFade = false;
  bool _saving = false;

  String _uiToApiTipo(String ui) {
    final low = ui.toLowerCase();
    if (low.contains('muj')) return 'mujeres';
    if (low.contains('homb')) return 'hombres';
    if (low.contains('mix')) return 'mixto';
    return ui.toLowerCase();
  }

  Future<void> _saveResidence() async {
    if (_saving) return;
    setState(() => _saving = true);
    final id = widget.residence.id;
    final apiTipo = _uiToApiTipo(tipoController.text);
    final body = {
      'nombre': nombreController.text.trim(),
      'tipo': apiTipo,
      'reglamentoUrl': reglamentoController.text.trim(),
      'descripcion': descripcionController.text.trim(),
      'telefonoContacto': telefonoController.text.trim(),
      'emailContacto': emailController.text.trim(),
      'servicios': serviciosSeleccionados.join(','),
    };

    try {
      // Usa el baseUrl dinámico según plataforma
      final uri = Uri.parse('${baseUrl}/api/residencias/$id');
      final res = await http.put(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Residencia actualizada')));
        // Actualiza la lista global automáticamente
        try {
          final provider = Provider.of<AuthProvider>(context, listen: false);
          await provider.reloadResidencias();
        } catch (_) {}
        Navigator.of(context).pop(true);
      } else {
        debugPrint('Update failed: ${res.statusCode} ${res.body}');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al actualizar: ${res.statusCode}')));
      }
    } catch (e) {
      debugPrint('Update exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error de red al actualizar')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _onScrollChanged() {
    final show = _scrollController.hasClients && _scrollController.offset > 6;
    if (show != _showHeaderFade) setState(() => _showHeaderFade = show);
  }

  Future<String?> _editHorarioRecepcion() async {
    // Busca si ya hay un servicio de horario de recepción con formato especial
    final existing = serviciosSeleccionados.firstWhere((e) => e.startsWith('Horario de recepción'), orElse: () => '');
    String mode = 'none'; // 'libre' | 'close' | 'none'
    TimeOfDay? closeTime;
    String? current;
    if (existing.isNotEmpty) {
      current = existing.split(':').sublist(1).join(':').trim();
      if (current == 'Libre') mode = 'libre';
      else if (current.startsWith('Cierra')) {
        mode = 'close';
        final parts = current.split(' ');
        if (parts.length >= 2) {
          final tpart = parts.sublist(1).join(' ').trim();
          if (tpart.contains(':')) {
            final p = tpart.split(':');
            if (p.length == 2) closeTime = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
          }
        }
      }
    }
    final result = await showModalBottomSheet<String?>(context: context, isScrollControlled: true, builder: (ctx) {
      String localMode = mode;
      TimeOfDay? localClose = closeTime;
      return StatefulBuilder(builder: (ctx2, setState2) {
        Future<void> pickClose() async {
          final t = await showTimePicker(context: ctx2, initialTime: localClose ?? const TimeOfDay(hour: 22, minute: 0));
          if (t != null) setState2(() => localClose = t);
        }
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx2).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(title: const Text('Libre (24/7)'), leading: Radio<String>(value: 'libre', groupValue: localMode, onChanged: (v) => setState2(() => localMode = v!))),
            ListTile(title: const Text('Hora de cierre'), leading: Radio<String>(value: 'close', groupValue: localMode, onChanged: (v) => setState2(() => localMode = v!))),
            if (localMode == 'close') Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Row(children: [
              Expanded(child: OutlinedButton(onPressed: pickClose, child: Text(localClose == null ? 'Seleccionar hora de cierre' : localClose!.format(ctx2)))),
            ])),
            ListTile(title: const Text('No disponible'), leading: Radio<String>(value: 'none', groupValue: localMode, onChanged: (v) => setState2(() => localMode = v!)) ),
            Padding(padding: const EdgeInsets.all(12), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.of(ctx2).pop(null), child: const Text('Cancelar')),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: () {
                if (localMode == 'libre') Navigator.of(ctx2).pop('Libre');
                else if (localMode == 'none') Navigator.of(ctx2).pop('');
                else if (localMode == 'close' && localClose != null) {
                  String fmt(TimeOfDay t) => t.hour.toString().padLeft(2,'0')+':'+t.minute.toString().padLeft(2,'0');
                  Navigator.of(ctx2).pop('Cierra ${fmt(localClose!)}');
                } else {
                  ScaffoldMessenger.of(ctx2).showSnackBar(const SnackBar(content: Text('Selecciona la hora de cierre')));
                }
              }, child: const Text('Guardar')),
            ]))
          ]),
        );
      });
    });
    if (result != null) return result.isEmpty ? null : result;
    return null;
  }

  Widget _styledField({required Widget child, IconData? icon, String? label}) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEAE7E1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBC7C0), width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0,2))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null)
              Row(
                children: [
                  if (icon != null) Icon(icon, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                  if (icon != null) const SizedBox(width: 6),
                  Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            if (label != null) const SizedBox(height: 2),
            child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, -2))],
            ),
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fixed header: remains visible while the form scrolls below
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // small drag handle
                    Center(
                      child: Container(
                        width: 48,
                        height: 4,
                        margin: const EdgeInsets.only(top: 6, bottom: 8),
                        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    Text('Editar Residencia', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                  ]),
                  // subtle fade to visually separate header from scrollable content
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: _showHeaderFade ? 1.0 : 0.0,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, theme.scaffoldBackgroundColor.withOpacity(0.98)],
                        ),
                      ),
                    ),
                  ),
                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          _styledField(
                            icon: Icons.home,
                            label: 'Nombre *',
                            child: TextFormField(
                              controller: nombreController,
                              decoration: const InputDecoration(border: InputBorder.none, hintText: 'Nombre'),
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                    const SizedBox(height: 8),
                    Text('Tipo de residencia', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tiposResidencia.map((tipo) => ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_tipoIcons[tipo], size: 18),
                            const SizedBox(width: 6),
                            Text(tipo, style: const TextStyle(fontFamily: 'Poppins')),
                          ],
                        ),
                        selected: tipo == (tipoController.text.isNotEmpty ? tipoController.text : 'Mixto'),
                        onSelected: (selected) {
                          if (selected) setState(() => tipoController.text = tipo);
                        },
                        selectedColor: theme.colorScheme.primary.withOpacity(0.15),
                        backgroundColor: theme.cardColor,
                        labelStyle: theme.textTheme.bodyMedium,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      )).toList(),
                    ),
                    const SizedBox(height: 8),
                    _styledField(
                      icon: Icons.picture_as_pdf,
                      label: 'Reglamento (URL)',
                      child: TextFormField(
                        controller: reglamentoController,
                        decoration: const InputDecoration(border: InputBorder.none, hintText: 'URL del reglamento'),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _styledField(
                      icon: Icons.description,
                      label: 'Descripción',
                      child: TextFormField(
                        controller: descripcionController,
                        decoration: const InputDecoration(border: InputBorder.none, hintText: 'Descripción'),
                        maxLines: 3,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _styledField(
                      icon: Icons.phone,
                      label: 'Teléfono de contacto',
                      child: TextFormField(
                        controller: telefonoController,
                        decoration: const InputDecoration(border: InputBorder.none, hintText: 'Teléfono'),
                        keyboardType: TextInputType.phone,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _styledField(
                      icon: Icons.email,
                      label: 'Email de contacto',
                      child: TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(border: InputBorder.none, hintText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Servicios', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: servicios.map((servicio) {
                        final selected = serviciosSeleccionados.any((e) => e == servicio || e.startsWith('$servicio:'));
                        final icon = servicioIcons[servicio] ?? Icons.check_box;
                        final match = serviciosSeleccionados.firstWhere((e) => e == servicio || e.startsWith('$servicio:'), orElse: () => '');
                        final label = (match.isNotEmpty && match.startsWith('$servicio:')) ? match : servicio;
                        return GestureDetector(
                          onTap: () async {
                            if (servicio == 'Horario de recepción') {
                              final res = await _editHorarioRecepcion();
                              setState(() {
                                serviciosSeleccionados.removeWhere((e) => e.startsWith('Horario de recepción'));
                                if (res != null && res.isNotEmpty) serviciosSeleccionados.add('Horario de recepción: $res');
                              });
                              return;
                            }
                            setState(() {
                              if (selected) {
                                serviciosSeleccionados.removeWhere((e) => e == servicio || e.startsWith('$servicio:'));
                              } else {
                                serviciosSeleccionados.add(servicio);
                              }
                            });
                          },
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 120, maxWidth: 180),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: selected ? theme.colorScheme.primary.withOpacity(0.12) : theme.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: selected ? theme.colorScheme.primary : Colors.transparent, width: 1.2),
                              boxShadow: selected ? [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.08), blurRadius: 6, offset: const Offset(0,2))] : null,
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: selected ? theme.colorScheme.primary : theme.dividerColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(icon, size: 18, color: selected ? Colors.white : theme.iconTheme.color),
                              ),
                              const SizedBox(width: 12),
                              Flexible(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: selected ? theme.colorScheme.primary : theme.textTheme.bodyMedium?.color))),
                            ]),
                          ),
                        );
                      }).toList(),
                    ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                textStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              onPressed: _saving ? null : () async {
                                await _saveResidence();
                              },
                              child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Guardar'),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
