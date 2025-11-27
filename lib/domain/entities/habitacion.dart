class Habitacion {
  final int? id;
  final String nombre;
  final String descripcion;
  final double precioMensual;
  final int residenciaId;
  final String? residenciaNombre;
  final List<String> imagenes;
  final bool disponible;
  final double? area; // en m²
  final int? capacidad;
  final List<String>? servicios;
  final String? tipo; // 'individual', 'compartida'
  
  Habitacion({
    this.id,
    required this.nombre,
    required this.descripcion,
    required this.precioMensual,
    required this.residenciaId,
    this.residenciaNombre,
    this.imagenes = const [],
    this.disponible = true,
    this.area,
    this.capacidad,
    this.servicios,
    this.tipo,
  });
  
  factory Habitacion.fromJson(Map<String, dynamic> json) {
    return Habitacion(
      id: json['id'],
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'] ?? '',
      precioMensual: (json['precio_mensual'] ?? 0).toDouble(),
      residenciaId: json['residencia_id'] ?? 0,
      residenciaNombre: json['residencia_nombre'],
      imagenes: json['imagenes'] != null 
        ? List<String>.from(json['imagenes']) 
        : [],
      disponible: json['disponible'] ?? true,
      area: json['area']?.toDouble(),
      capacidad: json['capacidad'],
      servicios: json['servicios'] != null 
        ? List<String>.from(json['servicios']) 
        : null,
      tipo: json['tipo'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'precio_mensual': precioMensual,
      'residencia_id': residenciaId,
      'residencia_nombre': residenciaNombre,
      'imagenes': imagenes,
      'disponible': disponible,
      'area': area,
      'capacidad': capacidad,
      'servicios': servicios,
      'tipo': tipo,
    };
  }
}
