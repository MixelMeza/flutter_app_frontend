import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class ProfilePhotoViewer extends StatelessWidget {
  final Uint8List? bytes;
  final String? url;

  const ProfilePhotoViewer({super.key, this.bytes, this.url}) : assert(bytes != null || url != null);

  @override
  Widget build(BuildContext context) {
    final imageProvider = bytes != null ? MemoryImage(bytes!) : NetworkImage(url!) as ImageProvider;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: PhotoView(
          imageProvider: imageProvider,
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3,
        ),
      ),
    );
  }
}
