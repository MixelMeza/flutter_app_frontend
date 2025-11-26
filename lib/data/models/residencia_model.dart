import '../../domain/entities/ubicacion.dart';

class ResidenciaModel {
  final int? id;
  final String nombre;
  final String? descripcion;
  final List<String>? servicios;
  final String? tipo;
  final String? reglamentoUrl;
  final String? estado;
  final Ubicacion? ubicacion;
  final String? contacto;
  final String? email;
  final int? universidadId;

  ResidenciaModel({this.id, required this.nombre, this.descripcion, this.servicios, this.tipo, this.reglamentoUrl, this.estado, this.ubicacion, this.contacto, this.email, this.universidadId});

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      if (descripcion != null) 'descripcion': descripcion,
      if (tipo != null) 'tipo': tipo,
      if (reglamentoUrl != null) 'reglamentoUrl': reglamentoUrl,
      // Backend expects servicios as a single comma-separated string.
      if (servicios != null) 'servicios': (servicios is List) ? (servicios as List).join(', ') : servicios,
      if (estado != null) 'estado': estado,
      if (ubicacion != null) 'ubicacion': ubicacion!.toJson(),
      // Backend expects different contact keys
      if (contacto != null) 'telefonoContacto': contacto,
      if (email != null) 'emailContacto': email,
      if (universidadId != null) 'universidad': {'id': universidadId},
    };
  }

  static ResidenciaModel fromMap(Map<String, dynamic> m) {
    return ResidenciaModel(
      id: (() {
        final v = m['id'];
        if (v == null) return null;
        if (v is int) return v;
        if (v is num) return v.toInt();
        final parsed = int.tryParse(v.toString());
        return parsed;
      })(),
      nombre: m['nombre'] as String? ?? 'Residencia',
      descripcion: m['descripcion'] as String?,
        servicios: (m['servicios'] is List)
          ? List<String>.from(m['servicios'])
          : (m['servicios'] is String)
            ? (m['servicios'] as String).split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
            : null,
      tipo: m['tipo'] as String?,
      reglamentoUrl: m['reglamentoUrl'] as String?,
      estado: m['estado'] as String?,
      ubicacion: null,
      contacto: m['telefonoContacto'] as String? ?? m['contacto'] as String?,
      email: m['emailContacto'] as String? ?? m['email'] as String?,
      universidadId: (() {
        if (m['universidad'] is Map) {
          final v = m['universidad']['id'];
          if (v == null) return null;
          if (v is int) return v;
          if (v is num) return v.toInt();
          return int.tryParse(v.toString());
        }
        return null;
      })(),
    );
  }
}
