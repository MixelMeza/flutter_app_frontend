/// Google Maps configuration. Store API key here.
/// Note: For production, consider keeping the API key out of source code and
/// loading it from a secure environment variable or native config.
library;

import 'package:google_maps_flutter/google_maps_flutter.dart';

const String googleMapsApiKey = 'AIzaSyB0ZU27ssbfOwWV2DVTUa0-UbidtoiuvDM';

/// Default explore map coordinate used as a safe fallback when device
/// location is unavailable.
const LatLng exploreDefault = LatLng(-11.9897619, -76.8376571);
