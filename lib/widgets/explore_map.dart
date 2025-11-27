import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

/// Simple ExploreMap centered on Universidad Peruana Unión.
/// No search bar, no debug badge, no markers — just a centered interactive map.
class ExploreMap extends StatefulWidget {
  final LatLng? initialPosition;
  const ExploreMap({super.key, this.initialPosition});

  @override
  State<ExploreMap> createState() => _ExploreMapState();
}

class _ExploreMapState extends State<ExploreMap> {
  final Completer<GoogleMapController> _controller = Completer();
  StreamSubscription<Position>? _positionSub;
  LatLng? _devicePosition;
  bool _hasLocationPermission = false;
  bool _autoFollow =
      true; // when true, camera recenters automatically to device position

  // Universidad Peruana Unión coordinates (fallback)
  static const LatLng _upeLatLng = LatLng(-11.9897619, -76.8376571);
  // Determine the effective initial camera based on optional widget.initialPosition
  CameraPosition get _initialCamera =>
      CameraPosition(target: widget.initialPosition ?? _upeLatLng, zoom: 16.14);

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // If opened in explore mode (no single initialPosition), load simulated markers
    if (widget.initialPosition == null) {
      // In explore mode, request location permission and start following device
      _initLocationTracking();
      // Load simulated markers quickly; use default/tinted markers to avoid
      // any heavy image decoding or asset loading on the UI thread.
      _loadSimulatedMarkers();
    } else {
      // when viewing a single location, mark it
      _markers = {
        Marker(
          markerId: const MarkerId('selected'),
          position: widget.initialPosition!,
        ),
      };
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
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return;
      }

      _hasLocationPermission = true;
      setState(() {});

      // get current position once
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 5),
        );
        _devicePosition = LatLng(pos.latitude, pos.longitude);
        // center initially if in explore mode
        if (_autoFollow && mounted) {
          _goTo(_devicePosition!, zoom: 16.14);
        }
      } catch (_) {}

      // subscribe to position updates (distanceFilter reduces updates)
      _positionSub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
              distanceFilter: 10,
            ),
          ).listen((Position p) {
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

  // coordinate logging helpers removed (not needed in UI build)

  Future<void> _goTo(LatLng pos, {double zoom = 16.14}) async {
    final controller = await _controller.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: pos, zoom: zoom)),
    );
  }

  // Simulate loading marker list from JSON and build Marker set
  Future<void> _loadSimulatedMarkers() async {
    final simulated = <Map<String, dynamic>>[
      {
        'id': 1,
        'nombre': 'Residencia A',
        'lat': -11.98945,
        'lng': -76.84312,
        'tipo': 'residencia',
      },
      {
        'id': 2,
        'nombre': 'Cafetería',
        'lat': -11.98990,
        'lng': -76.83850,
        'tipo': 'local',
      },
      {
        'id': 3,
        'nombre': 'Residencia B',
        'lat': -11.99050,
        'lng': -76.84020,
        'tipo': 'residencia',
      },
      {
        'id': 4,
        'nombre': 'Parque',
        'lat': -11.98880,
        'lng': -76.83900,
        'tipo': 'parque',
      },
      {
        'id': 5,
        'nombre': 'Residencia C',
        'lat': -11.98750,
        'lng': -76.84200,
        'tipo': 'residencia',
      },
    ];
    // First render markers quickly using the default/tinted marker to avoid blocking UI.
    final quickMarkers = <Marker>{};
    for (final e in simulated) {
      final pos = LatLng(
        (e['lat'] as num).toDouble(),
        (e['lng'] as num).toDouble(),
      );
      final isResidencia = (e['tipo']?.toString() ?? '') == 'residencia';
      // use quick tinted marker to avoid any heavy decoding
      final icon = isResidencia
          ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure)
          : BitmapDescriptor.defaultMarker;

      quickMarkers.add(
        Marker(
          markerId: MarkerId('m_${e['id']}'),
          position: pos,
          icon: icon,
          infoWindow: InfoWindow(
            title: e['nombre']?.toString(),
            snippet: e['tipo']?.toString(),
          ),
          onTap: () => debugPrint('[ExploreMap] tapped marker ${e['nombre']}'),
        ),
      );
    }

    setState(() {
      _markers = quickMarkers;
    });

    // NOTE: skip loading/replacing markers with a custom bitmap here to avoid
    // heavy image decoding on startup that can block the UI (ANR). We keep the
    // quickMarkers shown above and rely on default/tinted markers for performance.
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
          child: Stack(
            children: <Widget>[
              GoogleMap(
                // Ensure the GoogleMap consumes gestures so parent scrolls/pageviews
                // don't intercept drags and swipes while interacting with the map.
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                  ),
                },
                mapType: MapType.normal,
                initialCameraPosition: _initialCamera,
                markers: _markers,
                onMapCreated: (GoogleMapController controller) {
                  if (!_controller.isCompleted)
                    _controller.complete(controller);
                },
                myLocationEnabled: _hasLocationPermission,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: true,
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
                onTap: (pos) {
                  // tap to recenter camera smoothly
                  _goTo(pos);
                },
              ),

              // Using native Google Map controls (my-location + zoom controls)
            ],
          ),
        ),
      ),
    );
  }
}
