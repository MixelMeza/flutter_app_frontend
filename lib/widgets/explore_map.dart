import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Simple ExploreMap centered on Universidad Peruana Unión.
/// No search bar, no debug badge, no markers — just a centered interactive map.
class ExploreMap extends StatefulWidget {
  const ExploreMap({Key? key}) : super(key: key);

  @override
  State<ExploreMap> createState() => _ExploreMapState();
}

class _ExploreMapState extends State<ExploreMap> {
  final Completer<GoogleMapController> _controller = Completer();

  // Universidad Peruana Unión coordinates
  static const LatLng _upeLatLng = LatLng(-11.9897619, -76.8376571);
  // Slightly wider zoom so the user sees surrounding area
  static const CameraPosition _initialCamera = CameraPosition(target: _upeLatLng, zoom: 16.14);

  @override
  void dispose() {
    // ensure any running timer is cancelled
    _logTimer?.cancel();
    super.dispose();
  }

  CameraPosition? _lastCameraPosition;
  Timer? _logTimer;
  bool _logging = false;

  void _startLogging({int seconds = 30, int intervalSeconds = 1}) {
    if (_logging) return;
    _logging = true;
    int elapsed = 0;
    print('[ExploreMap] Starting coordinate logging for $seconds seconds');
    _logTimer = Timer.periodic(Duration(seconds: intervalSeconds), (t) {
      elapsed += intervalSeconds;
      final pos = _lastCameraPosition?.target ?? _upeLatLng;
      final zoom = _lastCameraPosition?.zoom ?? _initialCamera.zoom;
      print('[ExploreMap] center: lat=${pos.latitude.toStringAsFixed(7)}, lng=${pos.longitude.toStringAsFixed(7)}, zoom=${zoom.toStringAsFixed(2)}');
      if (elapsed >= seconds) {
        _stopLogging();
      }
    });
    setState(() {});
  }

  void _stopLogging() {
    _logTimer?.cancel();
    _logTimer = null;
    _logging = false;
    print('[ExploreMap] Coordinate logging stopped');
    setState(() {});
  }

  Future<void> _goTo(LatLng pos, {double zoom = 16.14}) async {
    final controller = await _controller.future;
    await controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: pos, zoom: zoom)));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _initialCamera,
            onMapCreated: (GoogleMapController controller) {
              if (!_controller.isCompleted) _controller.complete(controller);
            },
            myLocationEnabled: false,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            // Keep last camera position updated so we can log center coords
            onCameraMove: (position) => _lastCameraPosition = position,
            // When the user taps the map, re-center there (no marker placed)
            onTap: (pos) {
              print('[ExploreMap] tap at lat=${pos.latitude}, lng=${pos.longitude}');
              _goTo(pos);
            },
          ),

          // Floating button to toggle periodic logging of coordinates
          //Positioned(
       //     right: 12,
         //   bottom: 24,
        //    child: FloatingActionButton.extended(
         //     heroTag: 'coordLogger',
          //    onPressed: () {
          //      if (_logging) _stopLogging();
           //     else _startLogging(seconds: 30, intervalSeconds: 1);
           //   },
          //    label: Text(_logging ? 'Stop coords' : 'Log coords'),
         //     icon: Icon(_logging ? Icons.stop_circle : Icons.location_searching),
        //    ),
        //  ),
        ],
      ),
    );
  }
}
