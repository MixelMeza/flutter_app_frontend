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
  static const LatLng _upeLatLng = LatLng(-11.9920871, -76.8372577);
  // Slightly wider zoom so the user sees surrounding area
  static const CameraPosition _initialCamera = CameraPosition(target: _upeLatLng, zoom: 14);

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _goTo(LatLng pos, {double zoom = 14}) async {
    final controller = await _controller.future;
    await controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: pos, zoom: zoom)));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: GoogleMap(
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
        // When the user taps the map, re-center there (no marker placed)
        onTap: (pos) => _goTo(pos),
      ),
    );
  }
}
