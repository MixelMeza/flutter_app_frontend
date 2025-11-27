class Contrato {
  final int? id;
  final int habitacionId;
  final String? habitacionNombre;
  final int inquilinoId;
  final String? inquilinoNombre;
  final int propietarioId;
  final String? propietarioNombre;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final double montoMensual;
  final String estado; // 'activo', 'pendiente', 'finalizado', 'cancelado'
  final String? documentoUrl;
  final DateTime? fechaCreacion;
  
  Contrato({
    this.id,
    required this.habitacionId,
    this.habitacionNombre,
    required this.inquilinoId,
    this.inquilinoNombre,
    required this.propietarioId,
    this.propietarioNombre,
    required this.fechaInicio,
    required this.fechaFin,
    required this.montoMensual,
    this.estado = 'pendiente',
    this.documentoUrl,
    this.fechaCreacion,
  });
  
  factory Contrato.fromJson(Map<String, dynamic> json) {
    return Contrato(
      id: json['id'],
      habitacionId: json['habitacion_id'] ?? 0,
      habitacionNombre: json['habitacion_nombre'],
      inquilinoId: json['inquilino_id'] ?? 0,
      inquilinoNombre: json['inquilino_nombre'],
      propietarioId: json['propietario_id'] ?? 0,
      propietarioNombre: json['propietario_nombre'],
      fechaInicio: DateTime.parse(json['fecha_inicio']),
      fechaFin: DateTime.parse(json['fecha_fin']),
      montoMensual: (json['monto_mensual'] ?? 0).toDouble(),
      estado: json['estado'] ?? 'pendiente',
      documentoUrl: json['documento_url'],
      fechaCreacion: json['fecha_creacion'] != null 
        ? DateTime.parse(json['fecha_creacion']) 
        : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'habitacion_id': habitacionId,
      'habitacion_nombre': habitacionNombre,
      'inquilino_id': inquilinoId,
      'inquilino_nombre': inquilinoNombre,
      'propietario_id': propietarioId,
      'propietario_nombre': propietarioNombre,
      'fecha_inicio': fechaInicio.toIso8601String(),
      'fecha_fin': fechaFin.toIso8601String(),
      'monto_mensual': montoMensual,
      'estado': estado,
      'documento_url': documentoUrl,
      'fecha_creacion': fechaCreacion?.toIso8601String(),
    };
  }
  
  bool get isActivo => estado == 'activo';
  bool get isPendiente => estado == 'pendiente';
  bool get isFinalizado => estado == 'finalizado';
}
