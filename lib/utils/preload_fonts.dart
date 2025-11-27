import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Preloads a minimal set of Poppins font files from Google Fonts and
/// registers them under the family name 'Poppins' so the app uses the
/// real font as soon as possible.
///
/// This is a pragmatic approach for mobile where network access is
/// usually available. If you prefer bundling fonts as assets, add the
/// font files to `assets/fonts/` and update `pubspec.yaml` instead.
Future<void> preloadPoppinsFonts() async {
  final urls = <String>[
    // Regular 400 (used for body)
    'https://fonts.gstatic.com/s/poppins/v21/pxiByp8kv8JHgFVrLDD4Z1xlFd2JQEk.woff2',
    // Medium/Bold 700 (used for headings)
    'https://fonts.gstatic.com/s/poppins/v21/pxiByp8kv8JHgFVrLCz7Z1xlFd2JQEk.woff2',
  ];

  final loader = FontLoader('Poppins');

  for (final url in urls) {
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final bytes = res.bodyBytes;
        final bd = ByteData.view(bytes.buffer);
        loader.addFont(Future.value(bd));
      }
    } catch (_) {
      // Silent catch: failure here shouldn't crash the app; GoogleFonts
      // will fallback to runtime fetching or system font.
    }
  }

  try {
    await loader.load();
  } catch (_) {
    // If loading fails, ignore — app can still run using fallback fonts.
  }
}
