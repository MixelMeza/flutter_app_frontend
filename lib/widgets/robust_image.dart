import 'dart:convert';
// dart:typed_data not needed currently

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// RobustImage handles many common image sources:
/// - empty/null -> placeholder
/// - data:...base64 (inline images)
/// - http/https -> network (cached)
/// - local asset paths (assets/...)
/// It falls back gracefully to a neutral placeholder when decoding fails.
class RobustImage extends StatelessWidget {
  final String? source;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const RobustImage({Key? key, required this.source, this.fit, this.width, this.height, this.borderRadius}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final s = source ?? '';
    Widget child;

    // Avoid passing double.infinity to underlying Image widgets — convert
    // infinite dimensions to null so Flutter uses constraints from parents.
    final double? effectiveWidth = (width != null && width!.isFinite) ? width : null;
    final double? effectiveHeight = (height != null && height!.isFinite) ? height : null;

    if (s.isEmpty) {
      child = _placeholder(width: effectiveWidth, height: effectiveHeight);
    } else if (s.startsWith('data:')) {
      if (kDebugMode) debugPrint('RobustImage: detected data URI, decoding...');
      // inline base64 data URI
      try {
        final comma = s.indexOf(',');
        final b64 = (comma >= 0) ? s.substring(comma + 1) : s;
        final bytes = base64Decode(b64);
        child = Image.memory(bytes, fit: fit ?? BoxFit.cover, width: effectiveWidth, height: effectiveHeight);
      } catch (_) {
        child = _placeholder(width: effectiveWidth, height: effectiveHeight);
      }
    } else if (s.startsWith('http://') || s.startsWith('https://')) {
      if (kDebugMode) debugPrint('RobustImage: loading network image: $s');
      child = CachedNetworkImage(
        imageUrl: s,
        placeholder: (c, url) => Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.2))),
        errorWidget: (c, url, err) => _placeholder(width: effectiveWidth, height: effectiveHeight),
        // Use imageBuilder so we get a fully configured Image widget with the
        // requested fit and dimensions — this avoids layout surprises where
        // CachedNetworkImage might return a raw provider that doesn't size.
        imageBuilder: (context, imageProvider) {
          if (kDebugMode) debugPrint('RobustImage: imageBuilder completed for: $s');
          return Image(image: imageProvider, fit: fit ?? BoxFit.cover, width: effectiveWidth, height: effectiveHeight);
        },
      );
    } else {
      // Treat as asset path (relative)
      try {
        child = Image.asset(s, fit: fit ?? BoxFit.cover, width: effectiveWidth, height: effectiveHeight);
      } catch (_) {
        child = _placeholder(width: effectiveWidth, height: effectiveHeight);
      }
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }

  Widget _placeholder({double? width, double? height}) {
    return Container(
      color: Colors.grey.shade200,
      width: width,
      height: height,
      child: const Center(child: Icon(Icons.image_outlined, size: 48, color: Color(0xFF044B49))),
    );
  }
}
