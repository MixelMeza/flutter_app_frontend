// Central API configuration
// Returns an appropriate base URL depending on the platform. On Android
// emulators, `localhost` must be accessed via 10.0.2.2. You can override
// the host here if needed for your environment.
import 'dart:io' show Platform;

String get baseUrl {
  // default dev URL (host machine)
  var url = 'http://localhost:8080';
  try {
    if (Platform.isAndroid) {
      // Android emulator (AVD) uses 10.0.2.2 to reach host localhost
      url = 'http://10.0.2.2:8080';
    }
  } catch (_) {
    // If Platform is not available (rare in some builds), keep default
  }
  return url;
}

Map<String, String> defaultJsonHeaders([String? token]) {
  final headers = <String, String>{
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
  return headers;
}
