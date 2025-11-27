import 'package:intl/intl.dart';

class Habitacion {
  final int? id;
  final int? residenciaId;
  final String? residenciaNombre;
  final String? codigoHabitacion;
  final String nombre;
  final bool departamento;
  final bool banoPrivado;
  final bool wifi;
  final bool amueblado;
  final int? piso;
  final int? capacidad;
  final String descripcion;
  final bool permitirMascotas;
  final bool agua;
  final bool luz;
  final double precioMensual;
  final String? estado;
  final bool destacado;
  final DateTime? createdAt;
  final List<String> imagenes;

  Habitacion({
    this.id,
    this.residenciaId,
    this.residenciaNombre,
    this.codigoHabitacion,
    required this.nombre,
    this.departamento = false,
    this.banoPrivado = false,
    this.wifi = false,
    this.amueblado = false,
    this.piso,
    this.capacidad,
    this.descripcion = '',
    this.permitirMascotas = false,
    this.agua = false,
    this.luz = false,
    this.precioMensual = 0.0,
    this.estado,
    this.destacado = false,
    this.createdAt,
    this.imagenes = const [],
  });

  factory Habitacion.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
      if (v is double) return v.toInt();
      return null;
    }

    double parseDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String) {
        try {
          return DateTime.parse(v);
        } catch (_) {
          try {
            return DateFormat("yyyy-MM-dd HH:mm:ss").parse(v);
          } catch (_) {
            return null;
          }
        }
      }
      return null;
    }

    // residencia can be an object or id
    int? residId;
    String? residNombre;
    if (json['residencia'] is Map) {
      residId = parseInt(json['residencia']['id']);
      residNombre = json['residencia']['nombre']?.toString();
    }
    residId ??= parseInt(json['residencia_id'] ?? json['residenciaId']);
    residNombre ??= json['residencia_nombre'] ?? json['residenciaNombre'];

    // imagenes: try several keys
    List<String> imgs = [];
    if (json['imagenes'] != null) imgs = List<String>.from(json['imagenes']);
    if (imgs.isEmpty && json['imagenes_habitacion'] != null) imgs = List<String>.from(json['imagenes_habitacion']);
    if (imgs.isEmpty && json['imagenesHabitacion'] != null) imgs = List<String>.from(json['imagenesHabitacion']);

    return Habitacion(
      id: parseInt(json['id']),
      residenciaId: residId,
      residenciaNombre: residNombre?.toString(),
      codigoHabitacion: json['codigo_habitacion'] ?? json['codigoHabitacion'],
      nombre: json['nombre'] ?? '',
      departamento: json['departamento'] == null ? false : (json['departamento'] is bool ? json['departamento'] : (json['departamento'].toString() == 'true')),
      banoPrivado: json['bano_privado'] == null ? false : (json['bano_privado'] is bool ? json['bano_privado'] : (json['bano_privado'].toString() == 'true')),
      wifi: json['wifi'] == null ? false : (json['wifi'] is bool ? json['wifi'] : (json['wifi'].toString() == 'true')),
      amueblado: json['amueblado'] == null ? false : (json['amueblado'] is bool ? json['amueblado'] : (json['amueblado'].toString() == 'true')),
      piso: parseInt(json['piso']),
      capacidad: parseInt(json['capacidad']),
      descripcion: json['descripcion'] ?? '',
      permitirMascotas: json['permitir_mascotas'] == null ? false : (json['permitir_mascotas'] is bool ? json['permitir_mascotas'] : (json['permitir_mascotas'].toString() == 'true')),
      agua: json['agua'] == null ? false : (json['agua'] is bool ? json['agua'] : (json['agua'].toString() == 'true')),
      luz: json['luz'] == null ? false : (json['luz'] is bool ? json['luz'] : (json['luz'].toString() == 'true')),
      precioMensual: parseDouble(json['precio_mensual'] ?? json['precioMensual'] ?? json['precio']),
      estado: json['estado']?.toString(),
      destacado: json['destacado'] == null ? false : (json['destacado'] is bool ? json['destacado'] : (json['destacado'].toString() == 'true')),
      createdAt: parseDate(json['created_at'] ?? json['createdAt'] ?? json['createdAtIso']),
      imagenes: imgs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'residencia_id': residenciaId,
      'codigo_habitacion': codigoHabitacion,
      'nombre': nombre,
      'departamento': departamento,
      'bano_privado': banoPrivado,
      'wifi': wifi,
      'amueblado': amueblado,
      'piso': piso,
      'capacidad': capacidad,
      'descripcion': descripcion,
      'permitir_mascotas': permitirMascotas,
      'agua': agua,
      'luz': luz,
      'precio_mensual': precioMensual,
      'estado': estado,
      'destacado': destacado,
      'created_at': createdAt?.toIso8601String(),
      'imagenes': imagenes,
    };
  }
}
