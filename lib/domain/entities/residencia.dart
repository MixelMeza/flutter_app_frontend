import 'ubicacion.dart';

class Residencia {
  final int? id;
  final String nombre;
  final String? descripcion;
  final List<String>? servicios;
  final String? tipo; // 'Para hombres' | 'Para mujeres' | 'Mixto'
  final String? reglamentoUrl;
  final String? estado;
  final Ubicacion? ubicacion;
  final int? universidadId;
  final String? contacto;
  final String? email;

  Residencia({this.id, required this.nombre, this.descripcion, this.servicios, this.tipo, this.reglamentoUrl, this.estado, this.ubicacion, this.universidadId, this.contacto, this.email});
}
