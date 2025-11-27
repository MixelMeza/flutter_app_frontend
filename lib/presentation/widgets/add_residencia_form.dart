import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../domain/entities/residencia.dart';
import '../../domain/entities/ubicacion.dart';
import '../../domain/usecases/create_residencia_usecase.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../presentation/providers/auth_provider.dart';
import '../../config/google_maps.dart';

/// Form UI that uses a CreateResidenciaUseCase injected (Clean Architecture)
class AddResidenciaForm extends StatefulWidget {
  final CreateResidenciaUseCase createUseCase;
  final String? jwt;
  const AddResidenciaForm({Key? key, required this.createUseCase, this.jwt}) : super(key: key);

  @override
  State<AddResidenciaForm> createState() => _AddResidenciaFormState();
}

class _AddResidenciaFormState extends State<AddResidenciaForm> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _reglamentoCtrl = TextEditingController();
  final _contactoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _distritoCtrl = TextEditingController();
  final _provinciaCtrl = TextEditingController();
  final _departamentoCtrl = TextEditingController();
  final Set<String> _selectedServicios = {};
  bool _useMyContact = true;
  final List<String> _availableServicios = [
    'Lavadora',
    'Comedor',
    'Limpieza',
    'Parking',
    'Sala de estudio',
    'Seguridad',
    'Horario de recepción',
  ];
  final Map<String, IconData> _serviceIcons = {
    'Lavadora': Icons.local_laundry_service,
    'Comedor': Icons.restaurant,
    'Limpieza': Icons.cleaning_services,
    'Parking': Icons.local_parking,
    'Sala de estudio': Icons.menu_book,
    'Seguridad': Icons.security,
    'Horario de recepción': Icons.schedule,
  };

  // Tipo selector
  String _tipo = 'Mixto';
  final Map<String, IconData> _tipoIcons = {
    'Para hombres': Icons.male,
    'Para mujeres': Icons.female,
    'Mixto': Icons.groups,
  };

  LatLng? _pickedLatLng;
  late CameraPosition _initialCamera;
  bool _loading = false;
  bool _isReverseGeocoding = false;
  // Locks to prevent editing administrative fields that were auto-filled.
  bool _distritoLocked = false;
  bool _provinciaLocked = false;
  bool _departamentoLocked = false;

  @override
  void initState() {
    super.initState();
    _initialCamera = const CameraPosition(target: LatLng(-12.046374, -77.042793), zoom: 13);
    // Prefill contacto/email from AuthProvider if available
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final p = auth.profile;
      if (p != null) {
        final phone = p['telefono'] ?? p['telefono_movil'] ?? p['telefono_celular'] ?? p['phone'] ?? p['telefono'] ?? '';
        final email = p['email'] ?? p['correo'] ?? '';
        if (phone != null && phone.toString().isNotEmpty) _contactoCtrl.text = phone.toString();
        if (email != null && email.toString().isNotEmpty) _emailCtrl.text = email.toString();
      }
    } catch (_) {}
  }

  Future<LatLng> _determineInitialMapPosition() async {
    // Priority: device location -> previously picked location -> explore default
    try {
      // If we've already picked a location for this form, prefer it only if device location isn't available
      // but we still try device location first.
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services disabled');
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) throw Exception('Location permission denied');

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best, timeLimit: const Duration(seconds: 5));
      return LatLng(pos.latitude, pos.longitude);
    } catch (e) {
      debugPrint('[MapPicker] device location not available: $e');
      // Fall back: if user previously picked a location use that, otherwise use exploreDefault
      if (_pickedLatLng != null) return _pickedLatLng!;
      try {
        // import exploreDefault from config
        return exploreDefault;
      } catch (_) {
        // Final fallback: the form's initial camera target
        return _initialCamera.target;
      }
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _reglamentoCtrl.dispose();
    _contactoCtrl.dispose();
    _emailCtrl.dispose();
    _direccionCtrl.dispose();
    _distritoCtrl.dispose();
    _provinciaCtrl.dispose();
    _departamentoCtrl.dispose();
    super.dispose();
  }

  Future<String?> _editHorarioRecepcion() async {
    // Determine current existing schedule stored inside servicios (if any)
    final existing = _selectedServicios.firstWhere((e) => e.startsWith('Horario de recepción'), orElse: () => '');
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

  Future<void> _reverseGeocodeAndFill(LatLng latlng) async {
    // Use Google Geocoding API to reverse lookup address components.
    debugPrint('[reverseGeocode] called with lat=${latlng.latitude}, lng=${latlng.longitude}');
    final messenger = ScaffoldMessenger.of(context);
    if (googleMapsApiKey.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Google Maps API key not set - cannot reverse-geocode')));
      return;
    }
    setState(() => _isReverseGeocoding = true);
    try {
      final url = Uri.parse('https://maps.googleapis.com/maps/api/geocode/json?latlng=${latlng.latitude},${latlng.longitude}&key=$googleMapsApiKey&language=es');
      debugPrint('[reverseGeocode] requesting URL: $url');
      final resp = await http.get(url).timeout(const Duration(seconds: 8));
      debugPrint('[reverseGeocode] HTTP response status: ${resp.statusCode}');
      if (resp.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(resp.body);
        debugPrint('[reverseGeocode] response body length: ${resp.body.length}');
        final results = (data['results'] as List?) ?? [];
        debugPrint('[reverseGeocode] status=${data['status']} results=${results.length}');
        if (data['status'] == 'OK' && results.isNotEmpty) {
          // Aggregate components across all results so we can still fill
          // administrative levels when an exact street+number isn't available.
          String? route;
          String? streetNumber;
          String? distrito;
          String? provincia;
          String? departamento;

          for (final r in results) {
            if (r is! Map<String, dynamic>) continue;
            final comps = (r['address_components'] as List?) ?? [];
            for (final comp in comps) {
              final types = List<String>.from((comp['types'] as List?) ?? []);
              final longName = comp['long_name'] as String?;
              debugPrint('[reverseGeocode] component: types=$types long_name=$longName');
              if (longName == null) continue;
              if (route == null && types.contains('route')) route = longName;
              if (streetNumber == null && types.contains('street_number')) streetNumber = longName;
              if (distrito == null && (types.contains('administrative_area_level_3') || types.contains('sublocality') || types.contains('locality') || types.contains('political'))) {
                distrito = longName;
              }
              if (provincia == null && types.contains('administrative_area_level_2')) provincia = longName;
              if (departamento == null && types.contains('administrative_area_level_1')) departamento = longName;
            }
          }

          debugPrint('[reverseGeocode] collected -> route=$route, streetNumber=$streetNumber, distrito=$distrito, provincia=$provincia, departamento=$departamento');

          if (!mounted) return;
          setState(() {
            final addrParts = <String>[];
            if (route != null && route.isNotEmpty) addrParts.add(route);
            if (streetNumber != null && streetNumber.isNotEmpty) addrParts.add(streetNumber);
            _direccionCtrl.text = addrParts.join(' ');
            _distritoCtrl.text = distrito ?? '';
            _provinciaCtrl.text = provincia ?? '';
            _departamentoCtrl.text = departamento ?? '';
            // Lock administrative fields that were populated so user doesn't
            // accidentally edit them — they can unlock with the pencil icon.
            _distritoLocked = (_distritoCtrl.text.trim().isNotEmpty);
            _provinciaLocked = (_provinciaCtrl.text.trim().isNotEmpty);
            _departamentoLocked = (_departamentoCtrl.text.trim().isNotEmpty);
          });
          // Do not display an error to the user if Google provided any useful
          // administrative components. Keep UI silent on partial success.
        } else {
          // Log full response body for diagnostics. We will try the fallback
          // silently; only show a visible error if both Google and fallback fail.
          debugPrint('[reverseGeocode] google response body: ${resp.body}');
          String? gmsg;
          try {
            final Map<String, dynamic> raw = json.decode(resp.body);
            gmsg = raw['error_message'] as String?;
          } catch (_) {}
          // Try a fallback using Nominatim (OpenStreetMap) if Google failed or is denied.
          try {
            final nomUrl = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${latlng.latitude}&lon=${latlng.longitude}&accept-language=es');
            debugPrint('[reverseGeocode] trying Nominatim fallback URL: $nomUrl');
            // Nominatim requires a valid User-Agent identifying the application and contact info.
            final nomResp = await http.get(nomUrl, headers: {
              'User-Agent': 'app_movil_flutter/1.0 (contact: dev@yourdomain.com)',
              'Accept': 'application/json'
            }).timeout(const Duration(seconds: 8));
            debugPrint('[reverseGeocode] nominatim status=${nomResp.statusCode} bodyLen=${nomResp.body.length}');
            if (nomResp.statusCode == 200) {
              final Map<String, dynamic> nomData = json.decode(nomResp.body);
              final addr = nomData['address'] as Map<String, dynamic>?;
              if (addr != null) {
                final ndistrito = addr['suburb'] ?? addr['neighbourhood'] ?? addr['city_district'] ?? addr['city'] ?? addr['town'] ?? addr['village'];
                final nprovincia = addr['county'] ?? addr['region'] ?? addr['state_district'];
                final ndepartamento = addr['state'] ?? addr['region'];
                final road = addr['road'] ?? addr['pedestrian'] ?? addr['residential'];
                final house = addr['house_number'] ?? addr['building'];
                if (!mounted) return;
                setState(() {
                  // Always replace `Dirección` when the user picks a new location
                  // so changes to location immediately reflect in the form.
                  final parts = <String>[];
                  if (road != null) parts.add(road);
                  if (house != null) parts.add(house);
                  _direccionCtrl.text = parts.join(' ');
                  _distritoCtrl.text = ndistrito ?? '';
                  _provinciaCtrl.text = nprovincia ?? '';
                  _departamentoCtrl.text = ndepartamento ?? '';
                  _distritoLocked = (_distritoCtrl.text.trim().isNotEmpty);
                  _provinciaLocked = (_provinciaCtrl.text.trim().isNotEmpty);
                  _departamentoLocked = (_departamentoCtrl.text.trim().isNotEmpty);
                });
                debugPrint('[reverseGeocode] nominatim collected -> direccion=${_direccionCtrl.text}, distrito=${_distritoCtrl.text}, provincia=${_provinciaCtrl.text}, departamento=${_departamentoCtrl.text}');
                // Success (fallback) — do not show an error. UI already updated.
                return;
              }
            } else {
              debugPrint('[reverseGeocode] nominatim response body: ${nomResp.body}');
            }
          } catch (e) {
            debugPrint('[reverseGeocode] nominatim fallback error: $e');
          }
          // If we reach here, both Google and Nominatim failed to provide useful info.
          if (mounted) messenger.showSnackBar(SnackBar(content: Text(gmsg == null ? 'No se encontró dirección para la ubicación seleccionada' : 'Error: $gmsg')));
        }
      } else {
        if (mounted) messenger.showSnackBar(SnackBar(content: Text('Error geocoding: ${resp.statusCode}')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error al obtener dirección: $e')));
    } finally {
      if (mounted) setState(() => _isReverseGeocoding = false);
    }
  }

  // No-op: services are managed via checklist below

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // require a selected location
    if (_pickedLatLng == null) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(const SnackBar(content: Text('Selecciona la ubicación en el mapa antes de crear')));
      return;
    }
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);

    final residencia = Residencia(
      nombre: _nombreCtrl.text.trim(),
      descripcion: _descripcionCtrl.text.trim().isEmpty ? null : _descripcionCtrl.text.trim(),
      tipo: _tipo,
      reglamentoUrl: _reglamentoCtrl.text.trim().isEmpty ? null : _reglamentoCtrl.text.trim(),
      servicios: _selectedServicios.isEmpty ? null : _selectedServicios.toList(),
      ubicacion: _pickedLatLng == null ? null : Ubicacion(
        lat: _pickedLatLng!.latitude,
        lon: _pickedLatLng!.longitude,
        direccion: _direccionCtrl.text.trim().isEmpty ? null : _direccionCtrl.text.trim(),
        distrito: _distritoCtrl.text.trim().isEmpty ? null : _distritoCtrl.text.trim(),
        provincia: _provinciaCtrl.text.trim().isEmpty ? null : _provinciaCtrl.text.trim(),
        departamento: _departamentoCtrl.text.trim().isEmpty ? null : _departamentoCtrl.text.trim(),
      ),
      contacto: _contactoCtrl.text.trim().isEmpty ? null : _contactoCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      // universidadId omitted from UI (fixed or assigned server-side)
      universidadId: null,
    );

    try {
      final result = await widget.createUseCase.call(residencia, jwt: widget.jwt ?? '');
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('Residencia creada')));
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar residencia')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    // Nombre
                    TextFormField(
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre *',
                        prefixIcon: Icon(Icons.home),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Nombre requerido' : null,
                    ),
                    const SizedBox(height: 12),

                    // Tipo selector (Para hombres / Para mujeres / Mixto)
                    Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('Tipo de residencia', style: Theme.of(context).textTheme.titleSmall))),
                    Wrap(spacing: 8, runSpacing: 8, children: _tipoIcons.keys.map((t) {
                      final sel = (_tipo == t);
                      final icon = _tipoIcons[t] ?? Icons.home;
                      return GestureDetector(
                        onTap: () => setState(() => _tipo = t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: sel ? Theme.of(context).colorScheme.primary.withOpacity(0.12) : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: sel ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 1.2),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(width: 32, height: 32, decoration: BoxDecoration(color: sel ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor, shape: BoxShape.circle), child: Icon(icon, size: 18, color: sel ? Colors.white : Theme.of(context).iconTheme.color)),
                            const SizedBox(width: 8),
                            Text(t, style: TextStyle(fontWeight: FontWeight.w600, color: sel ? Theme.of(context).colorScheme.primary : Theme.of(context).textTheme.bodyMedium?.color)),
                          ]),
                        ),
                      );
                    }).toList()),

                    const SizedBox(height: 12),

                    // Map picker next to address so user can select location early
                    ElevatedButton.icon(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        final initial = await _determineInitialMapPosition();
                        final latlng = await navigator.push<LatLng?>(MaterialPageRoute(builder: (_) => _FullScreenMapPicker(initial: initial)));
                        if (latlng != null) {
                          setState(() => _pickedLatLng = latlng);
                          await _reverseGeocodeAndFill(latlng);
                        }
                      },
                      icon: const Icon(Icons.map),
                      label: Row(children: [
                        Expanded(child: Text(_pickedLatLng == null ? 'Marcar ubicación en el mapa' : 'Ubicación: ${_pickedLatLng!.latitude.toStringAsFixed(4)}, ${_pickedLatLng!.longitude.toStringAsFixed(4)}')),
                        if (_isReverseGeocoding) const SizedBox(width: 8),
                        if (_isReverseGeocoding) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      ]),
                    ),
                    const SizedBox(height: 10),

                    // Dirección y administración (departamento/provincia/distrito)
                    TextFormField(
                      controller: _direccionCtrl,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.location_on), labelText: 'Dirección (ej. Av. Universitaria 100)', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
                    ),
                    const SizedBox(height: 10),

                    // Departamento + Provincia in one row
                    Row(children: [
                      Expanded(child: TextFormField(
                        controller: _departamentoCtrl,
                        readOnly: _departamentoLocked,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.place),
                          labelText: 'Departamento',
                          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                          suffixIcon: _departamentoLocked ? IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => setState(() => _departamentoLocked = false)) : null,
                        ),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: TextFormField(
                        controller: _provinciaCtrl,
                        readOnly: _provinciaLocked,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.map),
                          labelText: 'Provincia',
                          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                          suffixIcon: _provinciaLocked ? IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => setState(() => _provinciaLocked = false)) : null,
                        ),
                      )),
                    ]),
                    const SizedBox(height: 10),

                    // Distrito full width
                    TextFormField(
                      controller: _distritoCtrl,
                      readOnly: _distritoLocked,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.location_city),
                        labelText: 'Distrito',
                        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        suffixIcon: _distritoLocked ? IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => setState(() => _distritoLocked = false)) : null,
                      ),
                    ),
                    const SizedBox(height: 12),

                    

                    // Servicios checklist (predefined)
                    Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Servicios', style: Theme.of(context).textTheme.titleSmall))),
                    Wrap(spacing: 10, runSpacing: 10, children: _availableServicios.map((s) {
                      final selected = _selectedServicios.any((e) => e == s || e.startsWith('$s:'));
                      final icon = _serviceIcons[s] ?? Icons.check_box;
                      // label may include horario detail
                      final match = _selectedServicios.firstWhere((e) => e == s || e.startsWith('$s:'), orElse: () => '');
                      final label = (match.isNotEmpty && match.startsWith('$s:')) ? match : s;
                      return GestureDetector(
                        onTap: () async {
                          if (s == 'Horario de recepción') {
                            final res = await _editHorarioRecepcion();
                            setState(() {
                              _selectedServicios.removeWhere((e) => e.startsWith('Horario de recepción'));
                              if (res != null && res.isNotEmpty) _selectedServicios.add('Horario de recepción: $res');
                            });
                            return;
                          }
                          setState(() {
                            if (selected) {
                              _selectedServicios.removeWhere((e) => e == s || e.startsWith('$s:'));
                            } else {
                              _selectedServicios.add(s);
                            }
                          });
                        },
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 140, maxWidth: 220),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: selected ? Theme.of(context).colorScheme.primary.withOpacity(0.12) : Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 1.2),
                              boxShadow: selected ? [BoxShadow(color: Theme.of(context).colorScheme.primary.withOpacity(0.08), blurRadius: 6, offset: const Offset(0,2))] : null,
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              // circular icon background
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(icon, size: 18, color: selected ? Colors.white : Theme.of(context).iconTheme.color),
                              ),
                              const SizedBox(width: 12),
                              Flexible(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).textTheme.bodyMedium?.color))),
                            ]),
                          ),
                        ),
                      );
                    }).toList()),
                    const SizedBox(height: 12),

                    // Descripción (after servicios so user can reference selected services)
                    TextFormField(
                      controller: _descripcionCtrl,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.description),
                        labelText: 'Descripción',
                        hintText: 'Descripción breve: servicios, cercanía, extras',
                        filled: true,
                        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      ),
                      maxLines: 5,
                      minLines: 3,
                    ),
                    const SizedBox(height: 12),

                    // Reglamento (URL placeholder for later upload/preview)
                    TextFormField(
                      controller: _reglamentoCtrl,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.picture_as_pdf), labelText: 'Reglamento (URL o archivo)', hintText: 'Por ahora pega la URL o deja vacío'),
                    ),
                    const SizedBox(height: 12),

                    // Contacto / Email in one row
                    Row(children: [
                      Expanded(child: TextFormField(controller: _contactoCtrl, decoration: const InputDecoration(prefixIcon: Icon(Icons.phone), labelText: 'Contacto (tel)'), keyboardType: TextInputType.phone)),
                      const SizedBox(width: 8),
                      Expanded(child: TextFormField(controller: _emailCtrl, decoration: const InputDecoration(prefixIcon: Icon(Icons.email), labelText: 'Email de contacto'), keyboardType: TextInputType.emailAddress, validator: (v) { if (v == null || v.trim().isEmpty) return null; return v.contains('@') ? null : 'Email inválido'; })),
                    ]),
                    const SizedBox(height: 16),

                    // UseMyContact switch below contact fields (keeps it visible and related)
                    Row(children: [
                      Expanded(child: Text('Usar contacto de mi perfil', style: Theme.of(context).textTheme.bodyMedium)),
                      Switch(value: _useMyContact, onChanged: (v) {
                        setState(() => _useMyContact = v);
                        if (v) {
                          try {
                            final auth = Provider.of<AuthProvider>(context, listen: false);
                            final p = auth.profile;
                            final phone = p?['telefono'] ?? p?['telefono_movil'] ?? p?['phone'] ?? p?['telefono'] ?? '';
                            final email = p?['email'] ?? p?['correo'] ?? '';
                            if (phone != null) _contactoCtrl.text = phone.toString();
                            if (email != null) _emailCtrl.text = email.toString();
                          } catch (_) {}
                        }
                      })
                    ]),

                    const SizedBox(height: 18),
                    // Submit
                    _loading ? const Center(child: CircularProgressIndicator()) : ElevatedButton.icon(onPressed: _submit, icon: const Icon(Icons.save), label: const Text('Crear residencia')),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// Full-screen map picker returns a LatLng when user confirms selection
class _FullScreenMapPicker extends StatefulWidget {
  final LatLng initial;
  const _FullScreenMapPicker({Key? key, required this.initial}) : super(key: key);

  @override
  State<_FullScreenMapPicker> createState() => _FullScreenMapPickerState();
}

class _FullScreenMapPickerState extends State<_FullScreenMapPicker> {
  LatLng? _picked;
  final Completer<GoogleMapController> _controller = Completer();

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar ubicación'),
        actions: [
          TextButton(
            onPressed: _picked == null ? null : () => Navigator.of(context).pop(_picked),
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: Stack(children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: widget.initial, zoom: 14),
          onMapCreated: (c) => _controller.complete(c),
          onTap: (latlng) => setState(() => _picked = latlng),
          markers: _picked == null ? {} : {Marker(markerId: const MarkerId('picked'), position: _picked!)},
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: Column(
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: _picked == null ? 0.7 : 1.0,
                child: FloatingActionButton.small(
                  heroTag: 'center_pick',
                  tooltip: 'Centrar en la selección',
                  backgroundColor: Theme.of(context).colorScheme.primary, // primary accent
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onPressed: () async {
                    if (_picked == null) return;
                    final c = await _controller.future;
                    await c.animateCamera(CameraUpdate.newLatLngZoom(_picked!, 16));
                  },
                  child: const Icon(Icons.my_location, size: 18),
                ),
              ),
              const SizedBox(height: 8),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: 1.0,
                child: FloatingActionButton.small(
                  heroTag: 'pick_here',
                  tooltip: 'Marcar centro del mapa',
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onPressed: () async {
                    // Use current visible region center as the picked location so
                    // user can move the map and tap 'pick here' to select it.
                    final c = await _controller.future;
                    try {
                      final bounds = await c.getVisibleRegion();
                      final centerLat = (bounds.northeast.latitude + bounds.southwest.latitude) / 2;
                      final centerLng = (bounds.northeast.longitude + bounds.southwest.longitude) / 2;
                      setState(() => _picked = LatLng(centerLat, centerLng));
                    } catch (e) {
                      // fallback: do nothing, user can still tap to pick
                      debugPrint('pick_here error: $e');
                    }
                  },
                  child: const Icon(Icons.center_focus_strong, size: 18),
                ),
              ),
              const SizedBox(height: 8),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: _picked == null ? 0.6 : 1.0,
                child: FloatingActionButton.small(
                  heroTag: 'clear_pick',
                  tooltip: 'Eliminar selección',
                  backgroundColor: const Color(0xFFFFB3C1), // soft pink
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onPressed: () => setState(() => _picked = null),
                  child: const Icon(Icons.clear, size: 18),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
