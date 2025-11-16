import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'dart:ui' as ui;

/// A full-screen cropper widget that receives raw image bytes and returns
/// the cropped bytes when the user confirms. It centers the image and
/// exposes a rectangular crop area that the user can move/zoom.
class PhotoCropperPage extends StatefulWidget {
  final Uint8List imageBytes;

  const PhotoCropperPage({Key? key, required this.imageBytes}) : super(key: key);

  @override
  State<PhotoCropperPage> createState() => _PhotoCropperPageState();
}

class _PhotoCropperPageState extends State<PhotoCropperPage> {
  final _controller = CropController();
  bool _isLoading = false;
  Completer<Uint8List>? _cropCompleter;
  int? _origW;
  int? _origH;

  @override
  void initState() {
    super.initState();
    debugPrint('[PhotoCropper] init imageBytes=${widget.imageBytes.length}');
    // try to decode image size for debugging
    () async {
      try {
        final codec = await ui.instantiateImageCodec(widget.imageBytes);
        final frame = await codec.getNextFrame();
        if (!mounted) return;
        setState(() {
          _origW = frame.image.width;
          _origH = frame.image.height;
        });
        debugPrint('[PhotoCropper] decoded size=$_origW x $_origH');
      } catch (e) {
        debugPrint('[PhotoCropper] failed to decode image size: $e');
      }
    }();
  }

  Future<void> _onCropPressed() async {
    setState(() => _isLoading = true);
    try {
      // The package calls `onCropped` when the crop finishes, and
      // `controller.crop()` triggers that. The controller does not
      // return the bytes directly, so we use a Completer to await
      // the `onCropped` callback.
      _cropCompleter = Completer<Uint8List>();
      // safety timeout to avoid infinite spinner if crop never returns
      final timer = Timer(const Duration(seconds: 8), () {
        try {
          if (_cropCompleter != null && !_cropCompleter!.isCompleted) _cropCompleter!.completeError('crop timeout');
        } catch (_) {}
      });

      _controller.crop();
      final Uint8List cropped = await _cropCompleter!.future;
      timer.cancel();
      if (!mounted) return;
      Navigator.of(context).pop(cropped);
    } catch (e) {
      // ignore
      try {
        Navigator.of(context).pop();
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _cropCompleter = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustar foto'),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  if (_origW != null && _origH != null) Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text('Tamaño original: ${_origW} x ${_origH}'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: SizedBox(width: 140, height: 140, child: Image.memory(widget.imageBytes, fit: BoxFit.contain)),
                  ),
                  Expanded(
                    child: Builder(builder: (ctx) {
                try {
                  return Crop(
                    controller: _controller,
                    image: widget.imageBytes,
                    onCropped: (croppedData) {
                      if (_cropCompleter == null) return;
                      try {
                        final dynamic d = croppedData;
                        Uint8List? bytes;

                        // direct Uint8List
                        if (d is Uint8List) bytes = d;

                        // List<int>
                        if (bytes == null && d is List<int>) bytes = Uint8List.fromList(d);

                        // common property names
                        if (bytes == null) {
                          try {
                            final maybe = d.bytes;
                            if (maybe is Uint8List) bytes = maybe;
                            else if (maybe is List<int>) bytes = Uint8List.fromList(maybe);
                          } catch (_) {}
                        }
                        if (bytes == null) {
                          try {
                            final maybe = d.data;
                            if (maybe is Uint8List) bytes = maybe;
                            else if (maybe is List<int>) bytes = Uint8List.fromList(maybe);
                          } catch (_) {}
                        }
                        if (bytes == null) {
                          try {
                            final maybe = d.image;
                            if (maybe is Uint8List) bytes = maybe;
                            else if (maybe is List<int>) bytes = Uint8List.fromList(maybe);
                          } catch (_) {}
                        }

                        // ByteBuffer (view)
                        if (bytes == null) {
                          try {
                            final buff = d.buffer;
                            if (buff is ByteBuffer) {
                              bytes = Uint8List.view(buff);
                            }
                          } catch (_) {}
                        }

                        // toList/toBytes methods
                        if (bytes == null) {
                          try {
                            final maybe = d.toList();
                            if (maybe is List<int>) bytes = Uint8List.fromList(maybe);
                          } catch (_) {}
                        }

                        if (bytes != null && !_cropCompleter!.isCompleted) {
                          _cropCompleter!.complete(bytes);
                        } else {
                          if (!_cropCompleter!.isCompleted) _cropCompleter!.completeError('No bytes from crop result');
                        }
                      } catch (err) {
                        try {
                          if (!_cropCompleter!.isCompleted) _cropCompleter!.completeError(err.toString());
                        } catch (_) {}
                      }
                    },
                    withCircleUi: true,
                    baseColor: Colors.white,
                    maskColor: const Color.fromRGBO(0, 0, 0, 0.4),
                    cornerDotBuilder: (size, cornerIndex) => Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    ),
                  );
                } catch (err) {
                  debugPrint('[PhotoCropper] Crop build error: $err');
                  // Fallback: show the raw image so user can at least see it
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(padding: EdgeInsets.all(8), child: Text('No se pudo inicializar el recorte, vista alternativa')),
                      Image.memory(widget.imageBytes, width: 300, height: 300, fit: BoxFit.contain),
                    ],
                  );
                }
                    }),
                  ),
                  ],
                ),
              ),

            // Optional bottom controls
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    label: const Text('Cancelar'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700]),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _onCropPressed,
                    icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check),
                    label: const Text('Usar foto'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Ensure controller is disposed when widget is removed
// (optional: CropController may not require explicit dispose, but safe to include)
// Note: If CropController later exposes dispose(), call it here.
