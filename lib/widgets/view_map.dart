import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

import '../services/api_service.dart' as api_service;
import '../config/api.dart';
import '../config/google_maps.dart';

/// Read-only map view for centering and inspecting a single location.
/// Use `ViewMap(initialPosition: LatLng(...), title: '...')` to show a marker.
class ViewMap extends StatefulWidget {
  final LatLng initialPosition;
  final String? title;

  /// Optional raw `ubicacion` object coming from the API (may contain id,
  /// direccion, departamento, provincia, pais, etc.). If provided the view
  /// will expose an "Editar" action to change the location.
  final Map<String, dynamic>? ubicacion;
  const ViewMap({
    Key? key,
    required this.initialPosition,
    this.title,
    this.ubicacion,
  }) : super(key: key);

  @override
  State<ViewMap> createState() => _ViewMapState();
}

class _ViewMapState extends State<ViewMap> {
  final Completer<GoogleMapController> _controller = Completer();

  CameraPosition get _initialCamera =>
      CameraPosition(target: widget.initialPosition, zoom: 16.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Ubicación'),
        elevation: 0.5,
        actions: [
          if (widget.ubicacion != null)
            IconButton(
              icon: const Icon(Icons.edit_location),
              tooltip: 'Editar ubicación',
              onPressed: () async {
                final result = await Navigator.of(context).push<bool?>(
                  MaterialPageRoute(
                    builder: (_) => _EditLocationPage(
                      ubicacion: widget.ubicacion!,
                      initialPosition: widget.initialPosition,
                    ),
                  ),
                );
                if (result == true) Navigator.of(context).pop(true);
              },
            ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () async {
              final ctrl = await _controller.future;
              await ctrl.animateCamera(
                CameraUpdate.newCameraPosition(_initialCamera),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialCamera,
            markers: {
              Marker(
                markerId: const MarkerId('m'),
                position: widget.initialPosition,
              ),
            },
            onMapCreated: (c) {
              if (!_controller.isCompleted) _controller.complete(c);
            },
            myLocationEnabled: false,
            zoomControlsEnabled: false,
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 20,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title ?? 'Ubicación seleccionada',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${widget.initialPosition.latitude.toStringAsFixed(6)}, ${widget.initialPosition.longitude.toStringAsFixed(6)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditLocationPage extends StatefulWidget {
  final Map<String, dynamic> ubicacion;
  final LatLng initialPosition;
  const _EditLocationPage({
    Key? key,
    required this.ubicacion,
    required this.initialPosition,
  }) : super(key: key);

  @override
  State<_EditLocationPage> createState() => _EditLocationPageState();
}

class _EditLocationPageState extends State<_EditLocationPage> {
  late LatLng _marker;
  final Completer<GoogleMapController> _ctrl = Completer();
  CameraPosition? _initialCamera;
  LatLng? _cameraTarget;
  bool _loading = false;

  // editable only: direccion
  late TextEditingController _direccionController;

  // auto-filled (read-only): departamento, provincia, distrito, pais
  String? _departamento;
  String? _provincia;
  String? _pais;
  String? _distrito;

  @override
  void initState() {
    super.initState();
    _marker = widget.initialPosition;
    _direccionController = TextEditingController(
      text: _pickString(widget.ubicacion, [
        'direccion',
        'ubicacion',
        'address',
      ]),
    );
    _departamento = _pickString(widget.ubicacion, [
      'departamento',
      'region',
      'state',
    ]);
    _provincia = _pickString(widget.ubicacion, ['provincia', 'county']);
    _pais = _pickString(widget.ubicacion, ['pais', 'country']);
    _distrito = _pickString(widget.ubicacion, ['distrito', 'district']);

    // Determine device position to center the map for editing. We prefer
    // device location so the user sees where they are and can move the map
    // under the centered cursor. Fall back to the current ubicacion.
    _determineInitialMapPosition().then((latlng) {
      if (!mounted) return;
      setState(() {
        _initialCamera = CameraPosition(target: latlng, zoom: 16.0);
        // Start the editable marker at device position (user requested)
        _marker = latlng;
        _cameraTarget = latlng;
      });
      // perform reverse-geocode for the starting point so fields are filled
      _reverseGeocodeAndFill(latlng);
    });
  }

  Future<LatLng> _determineInitialMapPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services disabled');
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied)
        throw Exception('Location permission denied');

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 6),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (e) {
      // fallback: use the existing ubicacion passed by the caller
      try {
        return widget.initialPosition;
      } catch (_) {
        return widget.initialPosition;
      }
    }
  }

  String? _pickString(Map m, List<String> keys) {
    for (final k in keys) {
      if (m.containsKey(k) && m[k] != null) return m[k].toString();
    }
    return null;
  }

  Future<void> _reverseGeocodeAndFill(LatLng latlng) async {
    if (googleMapsApiKey.isEmpty) return;
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${latlng.latitude},${latlng.longitude}&key=$googleMapsApiKey&language=es',
      );
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return;
      final Map<String, dynamic> data = json.decode(resp.body);
      if (data['results'] is! List || (data['results'] as List).isEmpty) return;
      final first = data['results'][0] as Map<String, dynamic>;
      final components = first['address_components'] as List<dynamic>;
      String? country, region, province, district, formatted;
      for (final c in components) {
        final types = (c['types'] as List<dynamic>).cast<String>();
        if (types.contains('country')) country = c['long_name'];
        if (types.contains('administrative_area_level_1'))
          region = c['long_name'];
        if (types.contains('administrative_area_level_2'))
          province = c['long_name'];
        if (types.contains('sublocality') ||
            types.contains('locality') ||
            types.contains('neighborhood'))
          district ??= c['long_name'];
      }
      formatted = first['formatted_address'] as String?;
      setState(() {
        _pais = country ?? _pais;
        _departamento = region ?? _departamento;
        _provincia = province ?? _provincia;
        _distrito = district ?? _distrito;
        if (formatted != null) _direccionController.text = formatted;
      });
    } catch (_) {
      // ignore reverse geocode errors silently
    }
  }

  int? _extractId(Map m) {
    if (m.containsKey('id'))
      return (m['id'] is int)
          ? m['id'] as int
          : int.tryParse(m['id'].toString());
    if (m.containsKey('uuid')) return int.tryParse(m['uuid'].toString());
    if (m.containsKey('ubicacionId'))
      return int.tryParse(m['ubicacionId'].toString());
    return null;
  }

  Future<void> _save() async {
    final id = _extractId(widget.ubicacion);
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID de ubicación no disponible')),
      );
      return;
    }
    setState(() => _loading = true);
    // Use the current camera target (center) if available, otherwise the
    // last known _marker position.
    final useLatLng = _cameraTarget ?? _marker;
    final payload = {
      'direccion': _direccionController.text,
      'departamento': _departamento,
      'distrito': _distrito,
      'provincia': _provincia,
      'pais': _pais,
      'latitud': useLatLng.latitude,
      'longitud': useLatLng.longitude,
    };
    final token = api_service.ApiService.authToken ?? '';
    final uri = Uri.parse('${baseUrl}/api/ubicaciones/$id');
    try {
      final resp = await http
          .put(
            uri,
            headers: defaultJsonHeaders(token),
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ubicación actualizada')));
        Navigator.of(context).pop(true);
        return;
      } else {
        final body = resp.body.isNotEmpty ? resp.body : '(${resp.statusCode})';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error actualizando: $body')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar ubicación')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition:
                      _initialCamera ??
                      CameraPosition(target: _marker, zoom: 16.0),
                  markers: {
                    // Old marker (original location) — shown for reference
                    Marker(
                      markerId: const MarkerId('old'),
                      position: widget.initialPosition,
                      infoWindow: const InfoWindow(title: 'Ubicación anterior'),
                    ),
                    // New/working marker — updated on camera idle
                    Marker(
                      markerId: const MarkerId('new'),
                      position: _cameraTarget ?? _marker,
                    ),
                  },
                  onMapCreated: (c) {
                    if (!_ctrl.isCompleted) _ctrl.complete(c);
                  },
                  onTap: (p) async {
                    final ctrl = await _ctrl.future;
                    await ctrl.animateCamera(CameraUpdate.newLatLng(p));
                  },
                  onCameraMove: (pos) {
                    // track moving camera center without heavy rebuilds
                    _cameraTarget = pos.target;
                  },
                  onCameraIdle: () async {
                    // when the camera stops moving, treat the center as selected
                    if (_cameraTarget != null) {
                      setState(() => _marker = _cameraTarget!);
                      await _reverseGeocodeAndFill(_cameraTarget!);
                    }
                  },
                  zoomControlsEnabled: false,
                ),
                // Center crosshair overlay so user sees the selection cursor in the middle
                IgnorePointer(
                  ignoring: true,
                  child: Center(
                    child: Icon(
                      Icons.place,
                      size: 44,
                      color: Theme.of(
                        context,
                      ).colorScheme.secondary.withOpacity(0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  controller: _direccionController,
                  decoration: const InputDecoration(labelText: 'Dirección'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text('Departamento: ${_departamento ?? '-'}'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(child: Text('Provincia: ${_provincia ?? '-'}')),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(child: Text('Distrito: ${_distrito ?? '-'}')),
                  ],
                ),
                const SizedBox(height: 4),
                Row(children: [Expanded(child: Text('País: ${_pais ?? '-'}'))]),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _save,
                        icon: _loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(
                          _loading ? 'Guardando...' : 'Guardar cambios',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
