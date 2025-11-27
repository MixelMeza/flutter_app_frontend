import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/residencia_model.dart';
import '../../services/api_service.dart';

class ResidenciaRemoteDataSource {
  final String baseUrl;
  final http.Client client;
  ResidenciaRemoteDataSource({required this.baseUrl, http.Client? client}) : client = client ?? http.Client();

  Future<Map<String, dynamic>> createResidencia(ResidenciaModel model, {String jwt = ''}) async {
    // Ensure we build a proper absolute URL (avoid literal "$baseUrl" in the string)
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final url = Uri.parse('$normalizedBase/api/residencias');
    // Prefer explicit jwt parameter; fall back to in-memory token from ApiService
    final effectiveToken = (jwt.isNotEmpty) ? jwt : (ApiService.authToken ?? '');
    final headers = <String, String>{'Content-Type': 'application/json', if (effectiveToken.isNotEmpty) 'Authorization': 'Bearer $effectiveToken'};

    final body = jsonEncode(model.toJson());
    // Diagnostic logs to help debug server 500 errors
    try {
      debugPrint('[ResidenciaRemote] POST $url');
      debugPrint('[ResidenciaRemote] headers: $headers');
      debugPrint('[ResidenciaRemote] body: $body');
    } catch (_) {}

      final resp = await client.post(url, headers: headers, body: body).timeout(const Duration(seconds: 10));
    // Log response headers and full body to aid debugging even when empty
    try {
      debugPrint('[ResidenciaRemote] response status=${resp.statusCode} bodyLen=${resp.body.length}');
      debugPrint('[ResidenciaRemote] response headers: ${resp.headers}');
      debugPrint('[ResidenciaRemote] response body: "${resp.body}"');
    } catch (_) {}
    if (resp.statusCode == 201) {
      if (resp.body.isEmpty) return <String, dynamic>{};
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    // include response body in exception for higher-level handling
    throw Exception('Error ${resp.statusCode}: ${resp.body}');
  }

  Future<List<Map<String, dynamic>>> getMyResidenciasSimple({String jwt = ''}) async {
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final url = Uri.parse('$normalizedBase/api/residencias/mine/simple');
    final effectiveToken = (jwt.isNotEmpty) ? jwt : (ApiService.authToken ?? '');
    final headers = <String, String>{'Content-Type': 'application/json', if (effectiveToken.isNotEmpty) 'Authorization': 'Bearer $effectiveToken'};

    try {
      debugPrint('[ResidenciaRemote] GET $url');
      debugPrint('[ResidenciaRemote] headers: $headers');
    } catch (_) {}

      final resp = await client.get(url, headers: headers).timeout(const Duration(seconds: 8));
    try {
      debugPrint('[ResidenciaRemote] response status=${resp.statusCode} bodyLen=${resp.body.length}');
      debugPrint('[ResidenciaRemote] response headers: ${resp.headers}');
      debugPrint('[ResidenciaRemote] response body: "${resp.body}"');
    } catch (_) {}

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.body.isEmpty) return [];
      final decoded = jsonDecode(resp.body);
      if (decoded is List) {
        return decoded.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      // If server returns a wrapped object {data: [...]}
      if (decoded is Map && decoded['data'] is List) {
        return (decoded['data'] as List).map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      throw Exception('Unexpected response shape for residencias/mine/simple');
    }

    throw Exception('Error ${resp.statusCode}: ${resp.body}');
  }

  Future<Map<String, dynamic>> getResidenciaById(int id, {String jwt = ''}) async {
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final url = Uri.parse('$normalizedBase/api/residencias/mine?id=$id');
    final effectiveToken = (jwt.isNotEmpty) ? jwt : (ApiService.authToken ?? '');
    final headers = <String, String>{'Content-Type': 'application/json', if (effectiveToken.isNotEmpty) 'Authorization': 'Bearer $effectiveToken'};

    try {
      debugPrint('[ResidenciaRemote] GET $url');
      debugPrint('[ResidenciaRemote] headers: $headers');
    } catch (_) {}

    final resp = await client.get(url, headers: headers).timeout(const Duration(seconds: 8));
    try {
      debugPrint('[ResidenciaRemote] response status=${resp.statusCode} bodyLen=${resp.body.length}');
      debugPrint('[ResidenciaRemote] response headers: ${resp.headers}');
      debugPrint('[ResidenciaRemote] response body: "${resp.body}"');
    } catch (_) {}

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.body.isEmpty) return <String, dynamic>{};
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) return decoded;
      // If server returns {data: {...}}
      if (decoded is Map && decoded['data'] is Map) return Map<String, dynamic>.from(decoded['data'] as Map);
      throw Exception('Unexpected response shape for residencias/{id}');
    }

    if (resp.statusCode == 401) {
      try { ApiService.notifyAuthError(); } catch (_) {}
    }
    throw Exception('Error ${resp.statusCode}: ${resp.body}');
  }
}
