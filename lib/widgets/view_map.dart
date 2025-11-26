import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Read-only map view for centering and inspecting a single location.
/// Use `ViewMap(initialPosition: LatLng(...), title: '...')` to show a marker.
class ViewMap extends StatefulWidget {
  final LatLng initialPosition;
  final String? title;
  const ViewMap({Key? key, required this.initialPosition, this.title}) : super(key: key);

  @override
  State<ViewMap> createState() => _ViewMapState();
}

class _ViewMapState extends State<ViewMap> {
  final Completer<GoogleMapController> _controller = Completer();

  CameraPosition get _initialCamera => CameraPosition(target: widget.initialPosition, zoom: 16.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Ubicación'),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () async {
              final ctrl = await _controller.future;
              await ctrl.animateCamera(CameraUpdate.newCameraPosition(_initialCamera));
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialCamera,
            markers: {Marker(markerId: const MarkerId('m'), position: widget.initialPosition)},
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.title ?? 'Ubicación seleccionada', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('${widget.initialPosition.latitude.toStringAsFixed(6)}, ${widget.initialPosition.longitude.toStringAsFixed(6)}', style: Theme.of(context).textTheme.bodyMedium),
                    ]),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cerrar'),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
