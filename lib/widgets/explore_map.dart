import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../theme.dart';
// api base helpers not required here; use ApiService
import '../services/api_service.dart' as api_service;
import 'robust_image.dart';
import 'package:url_launcher/url_launcher.dart';


/// Simple ExploreMap centered on Universidad Peruana Unión.
/// No search bar, no debug badge, no markers — just a centered interactive map.
class ExploreMap extends StatefulWidget {
  final LatLng? initialPosition;
  const ExploreMap({Key? key, this.initialPosition}) : super(key: key);

  // Public broadcast stream controller to request a reload from external callers.
  // Example: call `ExploreMap.requestReload()` from another widget.
  static final StreamController<void> _reloadController = StreamController<void>.broadcast();
  static void requestReload() => _reloadController.add(null);

  @override
  State<ExploreMap> createState() => _ExploreMapState();
}

class _ExploreMapState extends State<ExploreMap> {
  GoogleMapController? _mapController;
  // Queue camera updates when controller isn't ready; drain on onMapCreated.
  final List<CameraUpdate> _pendingCameraUpdates = <CameraUpdate>[];
  final GlobalKey _mapKey = GlobalKey();
  StreamSubscription<void>? _reloadSub;
  // Marker icon bitmaps cached as BitmapDescriptor
  BitmapDescriptor? _iconDefault; // white outer, maroon inner
  BitmapDescriptor? _iconSelected; // maroon outer, white inner
  String? _selectedMarkerId;
  Map<String, Map<String, dynamic>> _markerCards = {}; // cache for /api/residencias/{id}/card
  Map<String, dynamic>? _selectedCard;
  // Keep last loaded marker raw data so we can rebuild marker set quickly
  List<Map<String, dynamic>>? _lastMarkerData;
  StreamSubscription<Position>? _positionSub;
  LatLng? _devicePosition;
  bool _hasLocationPermission = false;
  bool _autoFollow = true; // when true, camera recenters automatically to device position
  // Previously we tracked a computed screen offset for the selected marker
  // to place controls under the marker. Controls are now fixed at
  // bottom-right so the on-screen offset is no longer required.

  // Universidad Peruana Unión coordinates (fallback)
  static const LatLng _upeLatLng = LatLng(-11.9897619, -76.8376571);
  // Determine the effective initial camera based on optional widget.initialPosition
  CameraPosition get _initialCamera => CameraPosition(target: widget.initialPosition ?? _upeLatLng, zoom: 16.14);

  @override
  void dispose() {
    // clear the reference first to avoid races where other async callbacks
    // attempt to use the old controller while we're disposing it.
    final _oldMapController = _mapController;
    _mapController = null;
    try {
      _oldMapController?.dispose();
    } catch (_) {}
    _positionSub?.cancel();
    _reloadSub?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Listen for external reload requests
    _reloadSub = ExploreMap._reloadController.stream.listen((_) {
      if (!mounted) return;
      debugPrint('[ExploreMap] external reload requested');
      _loadRemoteMarkers().catchError((e) => debugPrint('[ExploreMap] reload error: $e'));
    });
    // Prepare icons ahead of loading markers to ensure consistency
    _ensureMarkerIcons().catchError((e) => debugPrint('[ExploreMap] icon prepare error: $e'));
    // If opened in explore mode (no single initialPosition), load simulated markers
    if (widget.initialPosition == null) {
      // In explore mode, request location permission and start following device
      _initLocationTracking();
      // Try loading markers from backend endpoint; fall back to simulated markers
      _loadRemoteMarkers().catchError((_) => _loadSimulatedMarkers());
    } else {
      // when viewing a single location, mark it
      _markers = {
        Marker(markerId: const MarkerId('selected'), position: widget.initialPosition!),
      };
    }
  }

  // Update the on-screen widget offset for the selected marker so we can place
  // controls (zoom) directly under the marker icon. This converts the marker
  // LatLng to screen coordinates via the GoogleMapController.
  Future<void> _updateSelectedMarkerScreenPosition() async {
    if (_selectedMarkerId == null) return;
    try {
      final controller = _mapController;
      if (controller == null) return;
      if (_lastMarkerData == null) return;
      final idx = _lastMarkerData!.indexWhere((e) => ('m_${e['id']}') == _selectedMarkerId);
      if (idx == -1) return;
      final found = _lastMarkerData![idx];
      if (!found.containsKey('lat') || !found.containsKey('lng')) return;
      final pos = LatLng((found['lat'] as num).toDouble(), (found['lng'] as num).toDouble());
      if (!mounted) return;
      ScreenCoordinate sc;
      try {
        sc = await controller.getScreenCoordinate(pos);
      } catch (e) {
        if (kDebugMode) debugPrint('[ExploreMap] getScreenCoordinate failed: $e');
        return;
      }
      // sc.x/sc.y are in logical pixels relative to the map's top-left.
      final dx = sc.x.toDouble();
      final dy = sc.y.toDouble();
      // We intentionally do not store the screen coordinate anymore;
      // keep a debug trace so we can inspect values when needed.
      if (kDebugMode) debugPrint('[ExploreMap] selected marker screen coordinate: dx=$dx dy=$dy');
    } catch (e) {
      // ignore errors silently
    }
  }

  Future<void> _initLocationTracking() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // location services are disabled; don't crash, just skip enabling device location
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        return;
      }

      _hasLocationPermission = true;
      setState(() {});

      // get current position once
      try {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best, timeLimit: const Duration(seconds: 5));
        _devicePosition = LatLng(pos.latitude, pos.longitude);
        // center initially if in explore mode
        if (_autoFollow && mounted) {
          _goTo(_devicePosition!, zoom: 16.14);
        }
      } catch (_) {}

      // subscribe to position updates (distanceFilter reduces updates)
      _positionSub = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 10))
          .listen((Position p) {
        if (!mounted) return;
        _devicePosition = LatLng(p.latitude, p.longitude);
        if (_autoFollow && _devicePosition != null) {
          _goTo(_devicePosition!, zoom: 16.14);
        }
      });
    } catch (e) {
      debugPrint('[ExploreMap] location init failed: $e');
    }
  }


  // last camera position removed (not needed)
  Set<Marker> _markers = {};

  // Helper to safely animate the camera guarding against disposed controller.
  Future<void> _safeAnimate(CameraUpdate update) async {
    final c = _mapController;
    if (!mounted) return;
    if (c == null) {
      // Controller not ready yet; queue the update
      _pendingCameraUpdates.add(update);
      return;
    }
    try {
      await c.animateCamera(update);
    } catch (e) {
      if (kDebugMode) debugPrint('[ExploreMap] _safeAnimate failed: $e');
    }
  }

  // coordinate logging helpers removed (not needed in UI build)

  Future<void> _goTo(LatLng pos, {double zoom = 16.14}) async {
    final controller = _mapController;
    if (!mounted) return;
    if (controller == null) {
      // Queue until controller is ready
      _pendingCameraUpdates.add(CameraUpdate.newCameraPosition(CameraPosition(target: pos, zoom: zoom)));
      return;
    }
    try {
      await controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: pos, zoom: zoom)));
    } catch (e) {
      if (kDebugMode) debugPrint('[ExploreMap] _goTo animateCamera failed: $e');
    }
  }

  // Pan to a lat/lng but apply a vertical pixel offset so the marker appears
  // above center (useful when bottom sheets or info panels overlay the map).
  Future<void> _goToWithYOffset(LatLng pos, {double zoom = 16.14, double yOffset = 0.0}) async {
    final controller = _mapController;
    if (!mounted) return;
    if (controller == null) {
      // Fallback: queue simple goTo without offset (offset requires live controller)
      _pendingCameraUpdates.add(CameraUpdate.newCameraPosition(CameraPosition(target: pos, zoom: zoom)));
      return;
    }
    try {
      // meters per pixel at given latitude and zoom
      final metersPerPixel = 156543.03392 * math.cos(pos.latitude * math.pi / 180) / math.pow(2, zoom);
      const metersPerDegree = 111320.0;
      // positive yOffset moves the visible marker upwards on screen, so we
      // shift the camera center slightly south (subtract latitude).
      final latOffsetDegrees = (yOffset * metersPerPixel) / metersPerDegree;
      final target = LatLng(pos.latitude - latOffsetDegrees, pos.longitude);
      try {
        await controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: zoom)));
      } catch (e) {
        if (kDebugMode) debugPrint('[ExploreMap] _goToWithYOffset animateCamera failed: $e');
      }
    } catch (e) {
      // fallback to simple goTo on any error
      try {
        await controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: pos, zoom: zoom)));
      } catch (e2) {
        if (kDebugMode) debugPrint('[ExploreMap] _goToWithYOffset fallback animateCamera failed: $e2');
      }
    }
  }

  String _formatPrice(num? price) {
    if (price == null) return '';
    // simple formatter to show currency with thousands separator
    final p = price.toStringAsFixed(price is int ? 0 : 0);
    return '\$${p.replaceAllMapped(RegExp(r"\B(?=(\d{3})+(?!\d))"), (m) => ',')}';
  }

  String _formatDistanceKm(LatLng pos) {
    if (_devicePosition == null) return '';
    final meters = Geolocator.distanceBetween(_devicePosition!.latitude, _devicePosition!.longitude, pos.latitude, pos.longitude);
    if (meters < 1000) return '${(meters).round()} m';
    final km = (meters / 1000);
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
  }

  // Open a location in external Google Maps (or fallback to browser)
  Future<void> _openInExternalMaps(LatLng pos, String? label) async {
    try {
      final qLabel = (label ?? '').trim();
      final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}${qLabel.isNotEmpty ? '&query=${Uri.encodeComponent(qLabel)}' : ''}');
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        // fallback to browser mode
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se puede abrir Google Maps')));
    }
  }

  // Open directions to dest; if device position is available use as origin
  Future<void> _openDirectionsTo(LatLng dest) async {
    try {
      final origin = (_devicePosition != null) ? '${_devicePosition!.latitude},${_devicePosition!.longitude}' : '';
      final uriStr = origin.isNotEmpty
          ? 'https://www.google.com/maps/dir/?api=1&origin=${origin}&destination=${dest.latitude},${dest.longitude}&travelmode=driving'
          : 'https://www.google.com/maps/dir/?api=1&destination=${dest.latitude},${dest.longitude}&travelmode=driving';
      final uri = Uri.parse(uriStr);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se puede abrir la ruta')));
    }
  }

  Widget _buildBottomCard(BuildContext context, Map<String, dynamic> card, String markerId) {
    final img = (card['imagen_principal'] ?? card['imagen'] ?? '') as String?;
    final title = (card['nombre'] ?? '') as String;
    final rating = card['rating'];
    final price = card['precio_desde'] ?? card['precio'] ?? card['price'];
    final disponibles = card['habitaciones_disponibles'] ?? card['habitacionesDisponibles'];
    final total = card['habitaciones_totales'] ?? card['habitacionesTotales'];

    // Try to find the marker lat/lng for distance calculation
    LatLng? markerPos;
    if (_lastMarkerData != null) {
      final idx = _lastMarkerData!.indexWhere((e) => ('m_${e['id']}') == markerId);
      if (idx != -1) {
        final found = _lastMarkerData![idx];
        if (found.containsKey('lat') && found.containsKey('lng')) {
          markerPos = LatLng((found['lat'] as num).toDouble(), (found['lng'] as num).toDouble());
        }
      }
    }

    return LayoutBuilder(builder: (context, constraints) {
      final maxW = constraints.maxWidth.isFinite && constraints.maxWidth > 0
          ? constraints.maxWidth
          : MediaQuery.of(context).size.width - 24;
      final wide = maxW > 420;
      final imageHeight = wide ? 160.0 : 130.0;
      final titleSize = wide ? 20.0 : 16.0;
      final priceSize = wide ? 20.0 : 18.0;
      final badgeFont = wide ? 13.0 : 12.0;

      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Card(
            elevation: 14,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(18),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Image top
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: Stack(children: [
                    SizedBox(width: double.infinity, height: imageHeight, child: RobustImage(source: img, fit: BoxFit.cover, width: double.infinity, height: imageHeight)),
                    Positioned(left: 12, top: 12, child: Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: AppColors.maroon, borderRadius: BorderRadius.circular(22)), child: Text((card['tipo'] ?? '').toString().replaceFirstMapped(RegExp(r'^.'), (m) => m[0]!.toUpperCase()), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: badgeFont)))),
                  ]),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Title
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Poppins', fontSize: titleSize, fontWeight: FontWeight.w900, color: const Color(0xFF0B3A36))),
                    const SizedBox(height: 8),
                    // Rating and distance row
                    Row(children: [
                      if (rating != null) ...[
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 6),
                        Text((rating is num) ? rating.toString() : rating?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(width: 12),
                      ],
                      if (markerPos != null) ...[
                        const Icon(Icons.location_on, size: 14, color: Colors.black54),
                        const SizedBox(width: 6),
                        Text(_formatDistanceKm(markerPos), style: const TextStyle(color: Colors.black54)),
                      ],
                    ]),
                    const SizedBox(height: 12),
                    // Bottom row: left -> price block (expandido); right -> habitaciones above Ver detalles
                    Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      // Left column: price block expanded to take available space
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Text('Desde', style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          // price and '/mes' on same line, left aligned and large
                          Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(_formatPrice(price), textAlign: TextAlign.left, style: TextStyle(color: const Color(0xFFB33A3A), fontWeight: FontWeight.w900, fontSize: priceSize)),
                            const SizedBox(width: 6),
                            const Padding(padding: EdgeInsets.only(bottom: 2), child: Text('/mes', style: TextStyle(color: Colors.black54, fontSize: 12))),
                          ]),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      // Right column: habitaciones + details button
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        if (disponibles != null && total != null) ...[
                          Text('${disponibles}/${total} habitaciones', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                          const SizedBox(height: 8),
                        ],
                        SizedBox(
                          width: wide ? 160 : 140,
                          height: wide ? 44 : 40,
                          child: ElevatedButton(
                            onPressed: () {
                              // open details
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.maroon, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                            child: const Text('Ver detalles'),
                          ),
                        ),
                      ])
                    ])
                  ]),
                )
              ]),
            ),
          ),
        ),
      );
    });
  }



  // Simulate loading marker list from JSON and build Marker set
  Future<void> _loadSimulatedMarkers() async {
    final simulated = <Map<String, dynamic>>[
      {'id': 1, 'nombre': 'Residencia A', 'lat': -11.98945, 'lng': -76.84312, 'tipo': 'residencia'},
      {'id': 2, 'nombre': 'Cafetería', 'lat': -11.98990, 'lng': -76.83850, 'tipo': 'local'},
      {'id': 3, 'nombre': 'Residencia B', 'lat': -11.99050, 'lng': -76.84020, 'tipo': 'residencia'},
      {'id': 4, 'nombre': 'Parque', 'lat': -11.98880, 'lng': -76.83900, 'tipo': 'parque'},
      {'id': 5, 'nombre': 'Residencia C', 'lat': -11.98750, 'lng': -76.84200, 'tipo': 'residencia'},
    ];
    // ensure custom icons available
    await _ensureMarkerIcons();
    // store raw data for rebuilds
    _lastMarkerData = simulated;
    if (mounted) setState(() => _markers = _buildMarkersFromData(simulated));

    // NOTE: skip loading/replacing markers with a custom bitmap here to avoid
    // heavy image decoding on startup that can block the UI (ANR). We keep the
    // quickMarkers shown above and rely on default/tinted markers for performance.
  }

  // Load markers from backend endpoint /api/residencias/map
  Future<void> _loadRemoteMarkers() async {
    await _ensureMarkerIcons();
    try {
      final data = await api_service.ApiService.get('/api/residencias/map');
      if (data is! List) throw Exception('Invalid response for map');
      final normalized = <Map<String, dynamic>>[];
      for (final item in data) {
        if (item is! Map) continue;
        final latRaw = item['lat'] ?? item['latitud'];
        final lngRaw = item['lng'] ?? item['longitud'];
        if (latRaw == null || lngRaw == null) continue;
        normalized.add({
          'id': item['id'] ?? item['uuid'] ?? item['residenciaId'],
          'nombre': item['nombre']?.toString() ?? '',
          'tipo': item['tipo']?.toString() ?? '',
          'lat': (latRaw as num).toDouble(),
          'lng': (lngRaw as num).toDouble(),
        });
      }
      _lastMarkerData = normalized;
      if (mounted) setState(() => _markers = _buildMarkersFromData(normalized));
      // Preload card data in background for each marker (fire-and-forget)
      for (final item in normalized) {
        final id = item['id'];
        if (id != null) _preloadCard(id).catchError((e) => debugPrint('[ExploreMap] preload card $id failed: $e'));
      }
    } catch (e) {
      debugPrint('[ExploreMap] failed to load remote markers: $e');
      rethrow;
    }
  }

  // Preload the card data for a given residencia id and cache it.
  Future<void> _preloadCard(dynamic id) async {
    final key = 'm_${id.toString()}';
    if (_markerCards.containsKey(key)) return;
    try {
      final data = await api_service.ApiService.get('/api/residencias/${id.toString()}/card');
      if (data is! Map<String, dynamic>) throw Exception('Invalid card response');
      _markerCards[key] = data;
      // If currently selected marker matches this id, update selectedCard to show UI
      if (_selectedMarkerId == key && mounted) {
        setState(() => _selectedCard = data);
      }
    } catch (e) {
      debugPrint('[ExploreMap] error loading card for $id: $e');
    }
  }

  // Ensure card is loaded then open it (used when tapping marker)
  Future<void> _openCard(String markerId, dynamic apiId) async {
    // If cached, use immediately
    if (_markerCards.containsKey(markerId)) {
      setState(() {
        _selectedCard = _markerCards[markerId];
      });
      return;
    }
    // otherwise fetch and then show
    await _preloadCard(apiId);
    if (mounted) setState(() => _selectedCard = _markerCards[markerId]);
  }

  // Build markers from the given data and current selection state. This
  // returns a Set<Marker> so callers can assign into the state inside one setState.
  Set<Marker> _buildMarkersFromData(List<Map<String, dynamic>> data) {
    final rebuilt = <Marker>{};
    for (final e in data) {
      try {
        final id = e['id'];
        final markerId = 'm_${id}';
        final pos = LatLng((e['lat'] as num).toDouble(), (e['lng'] as num).toDouble());
        rebuilt.add(Marker(
          markerId: MarkerId(markerId),
          position: pos,
          // anchor the marker image at the tip (bottom center)
          anchor: const Offset(0.5, 1.0),
          zIndex: (_selectedMarkerId == markerId) ? 2.0 : 1.0,
          icon: (_selectedMarkerId == markerId) ? (_iconSelected ?? BitmapDescriptor.defaultMarker) : (_iconDefault ?? BitmapDescriptor.defaultMarker),
          // Disable the default InfoWindow tooltip so only our bottom card appears
          infoWindow: const InfoWindow(title: '', snippet: ''),
          consumeTapEvents: true,
          onTap: () {
            // Focus behavior: always select the tapped marker (do not toggle off).
            final newSel = markerId;
            if (_lastMarkerData != null) {
                setState(() {
                _selectedMarkerId = newSel;
                _markers = _buildMarkersFromData(_lastMarkerData!);
              });
            } else {
              setState(() { _selectedMarkerId = newSel; });
            }
            // Animate camera to the selected marker for better context (slightly closer)
            try {
              // move the camera and apply a vertical offset so the pin is visible
              _goToWithYOffset(pos, zoom: 17.0, yOffset: 120.0);
            } catch (_) {}
            // Open (or preload then open) the card overlay for this marker
            try {
              _openCard(markerId, e['id']);
            } catch (_) {}
            // After animations settle, compute marker screen position so zoom controls can be placed
            Future.delayed(const Duration(milliseconds: 450), () {
              _updateSelectedMarkerScreenPosition();
            });
          },
        ));
      } catch (_) {}
    }
    return rebuilt;
  }

  // Generate and cache the two marker BitmapDescriptors used for default and selected states.
  Future<void> _ensureMarkerIcons() async {
    if (_iconDefault != null && _iconSelected != null) return;
    // Sizes in pixels (higher resolution for retina clarity)
    const int size = 128;
    // Colors: default outer = white, inner dot = maroon. Selected inverts.
    final outerDefault = Colors.white;
    final outerMaroon = AppColors.maroon;
    final innerMaroon = AppColors.maroon;
    final innerWhite = Colors.white;

    Future<Uint8List> _createBytes(Color outer, Color inner) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..isAntiAlias = true;
      // Teardrop pin: tip at bottom, circular head above
      // Increase head proportion slightly and add soft shadow ellipse for depth.
      final center = Offset(size / 2, size * 0.36);
      paint.color = outer;
      final double headRadius = size * 0.34;

      // Draw soft shadow ellipse under the pin to simulate drop shadow
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.14)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      // shadow position slightly below head center
      final shadowRect = Rect.fromCenter(center: Offset(center.dx, center.dy + headRadius * 0.85), width: headRadius * 1.6, height: headRadius * 0.5);
      canvas.drawOval(shadowRect, shadowPaint);

      // outer head (upper)
      final outerPaint = Paint()..color = outer..isAntiAlias = true;
      canvas.drawCircle(center, headRadius, outerPaint);

      // triangle tail pointing down to the tip
      final tailPath = Path();
      tailPath.moveTo(size * 0.5, size * 0.94); // tip (bottom)
      tailPath.lineTo(size * 0.5 - headRadius * 0.72, center.dy + headRadius * 0.18);
      tailPath.lineTo(size * 0.5 + headRadius * 0.72, center.dy + headRadius * 0.18);
      tailPath.close();
      canvas.drawPath(tailPath, outerPaint);

      // subtle white border (stroke) to separate from map tiles
      final stroke = Paint()
        ..color = Colors.white.withOpacity(0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (size * 0.028).clamp(1.0, 6.0)
        ..isAntiAlias = true;
      canvas.drawCircle(center, headRadius, stroke);

      // Inner dot (colored head)
      paint.color = inner;
      final innerRadius = headRadius * 0.5;
      canvas.drawCircle(center, innerRadius, paint);

      // Convert to image
      final picture = recorder.endRecording();
      final img = await picture.toImage(size, size);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      return bytes!.buffer.asUint8List();
    }

    try {
      final bytesDefault = await _createBytes(outerDefault, innerMaroon);
      final bytesSelected = await _createBytes(outerMaroon, innerWhite);
      _iconDefault = BitmapDescriptor.fromBytes(bytesDefault);
      _iconSelected = BitmapDescriptor.fromBytes(bytesSelected);
      // If we already have loaded marker data, rebuild markers so new icons apply immediately.
      if (_lastMarkerData != null && mounted) {
        setState(() {
          _markers = _buildMarkersFromData(_lastMarkerData!);
        });
      }
    } catch (e) {
      debugPrint('[ExploreMap] failed to create marker icons: $e');
    }
  }

  // No programmatic marker generation: keep markers lightweight.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: null,
      body: SafeArea(
        top: true,
        bottom: false,
        child: SizedBox.expand(
          key: _mapKey,
          child: Stack(
            children: <Widget>[
              GoogleMap(
                // Ensure the GoogleMap consumes gestures so parent scrolls/pageviews
                // don't intercept drags and swipes while interacting with the map.
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                },
                mapType: MapType.normal,
                initialCameraPosition: _initialCamera,
                markers: _markers,
                onMapCreated: (GoogleMapController controller) {
                  // Replace any previous controller reference with the new one.
                  try {
                    _mapController?.dispose();
                  } catch (_) {}
                  _mapController = controller;
                  // Drain any queued camera updates
                  if (_pendingCameraUpdates.isNotEmpty) {
                    final updates = List<CameraUpdate>.from(_pendingCameraUpdates);
                    _pendingCameraUpdates.clear();
                    for (final u in updates) {
                      // ignore failures silently
                      controller.animateCamera(u).catchError((_) {});
                    }
                  }
                },
                myLocationEnabled: _hasLocationPermission,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                zoomGesturesEnabled: true,
                scrollGesturesEnabled: true,
                rotateGesturesEnabled: true,
                tiltGesturesEnabled: true,
                onCameraMove: (position) {
                // If the camera moved to device position, enable auto-follow; otherwise assume user panned
                if (_devicePosition != null) {
                  final dist = Geolocator.distanceBetween(
                    _devicePosition!.latitude,
                    _devicePosition!.longitude,
                    position.target.latitude,
                    position.target.longitude,
                  );
                  if (dist < 30.0) {
                    _autoFollow = true;
                  } else {
                    _autoFollow = false;
                  }
                }
                },
                onCameraIdle: () async {
                  // After camera stops, update the widget position of the selected marker so zoom controls follow it
                  await _updateSelectedMarkerScreenPosition();
                },
                onTap: (pos) async {
                    // tap to recenter camera smoothly and clear selection (focus behavior)
                    if (_selectedMarkerId != null) {
                      if (_lastMarkerData != null) {
                        setState(() {
                          _selectedMarkerId = null;
                                _markers = _buildMarkersFromData(_lastMarkerData!);
                                // previously cleared marker widget offset here; no longer used
                        });
                      } else {
                              setState(() { _selectedMarkerId = null; });
                      }
                    }
                    await _goTo(pos);
                  },
              ),

                  // Top-left control: center (single clear icon)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 4,
                      child: IconButton(
                        icon: const Icon(Icons.center_focus_strong, color: AppColors.maroon),
                        onPressed: () async {
                          try {
                            // If a marker is selected, center on that marker; otherwise center on device
                            if (_selectedMarkerId != null && _lastMarkerData != null) {
                              final idx = _lastMarkerData!.indexWhere((e) => ('m_${e['id']}') == _selectedMarkerId);
                              if (idx != -1) {
                                final f = _lastMarkerData![idx];
                                if (f.containsKey('lat') && f.containsKey('lng')) {
                                  await _goTo(LatLng((f['lat'] as num).toDouble(), (f['lng'] as num).toDouble()), zoom: 17.0);
                                  return;
                                }
                              }
                            }
                            if (_devicePosition != null) {
                              await _goTo(_devicePosition!, zoom: 16.14);
                            }
                          } catch (_) {}
                        },
                      ),
                    ),
                  ),

                  // Marker-specific actions (appear only when a marker is selected): open map / directions
                  Positioned(
                    top: 12,
                    left: 88,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: (_selectedMarkerId != null)
                          ? Builder(builder: (ctx) {
                              LatLng? selPos;
                              if (_lastMarkerData != null) {
                                final idx = _lastMarkerData!.indexWhere((e) => ('m_${e['id']}') == _selectedMarkerId);
                                if (idx != -1) {
                                  final f = _lastMarkerData![idx];
                                  if (f.containsKey('lat') && f.containsKey('lng')) selPos = LatLng((f['lat'] as num).toDouble(), (f['lng'] as num).toDouble());
                                }
                              }

                              return Row(children: [
                                if (selPos != null)
                                  Material(
                                    color: Colors.white,
                                    shape: const CircleBorder(),
                                    elevation: 4,
                                    child: IconButton(
                                      icon: const Icon(Icons.map, color: AppColors.maroon),
                                      onPressed: () async {
                                        await _openInExternalMaps(selPos!, (_selectedCard != null ? (_selectedCard!['nombre']?.toString() ?? '') : ''));
                                      },
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                if (selPos != null)
                                  Material(
                                    color: Colors.white,
                                    shape: const CircleBorder(),
                                    elevation: 4,
                                    child: IconButton(
                                      icon: const Icon(Icons.directions, color: AppColors.maroon),
                                      onPressed: () async {
                                        await _openDirectionsTo(selPos!);
                                      },
                                    ),
                                  ),
                              ]);
                            })
                          : const SizedBox.shrink(),
                    ),
                  ),

              // Zoom controls anchored to the bottom-right (custom controls).
              // The bottom card is rendered after these controls in the stack
              // so the card will visually overlay the controls when present.
              Positioned(
                right: 12,
                bottom: 14,
                child: Column(children: [
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 6,
                    child: IconButton(
                      icon: const Icon(Icons.zoom_in, color: AppColors.maroon),
                      onPressed: () async {
                        await _safeAnimate(CameraUpdate.zoomIn());
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 6,
                    child: IconButton(
                      icon: const Icon(Icons.zoom_out, color: AppColors.maroon),
                      onPressed: () async {
                        await _safeAnimate(CameraUpdate.zoomOut());
                      },
                    ),
                  ),
                ]),
              ),

              // Custom bottom card overlay when a marker is selected (placed
              // after zoom controls so it will overlay them when visible)
              Positioned(
                left: 12,
                right: 12,
                bottom: 14,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: (_selectedCard != null && _selectedMarkerId != null)
                      ? _buildBottomCard(context, _selectedCard!, _selectedMarkerId!)
                      : const SizedBox.shrink(),
                ),
              ),

              // Using native Google Map controls (my-location + zoom controls)
            ],
          ),
        ),
      ),
    );
  }
}
