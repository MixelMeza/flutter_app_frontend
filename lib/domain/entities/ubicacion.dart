class Ubicacion {
  final double? lat;
  final double? lon;
  final String? distrito;
  final String? provincia;
  final String? departamento;
  final String? direccion;

  Ubicacion({this.lat, this.lon, this.distrito, this.provincia, this.departamento, this.direccion});

  Map<String, dynamic> toJson() => {
    if (lat != null) 'lat': lat,
    if (lon != null) ...{
      'lon': lon,
      // include common alternative key 'lng' in case backend expects it
      'lng': lon,
    },
    if (distrito != null) 'distrito': distrito,
    if (provincia != null) 'provincia': provincia,
    if (departamento != null) 'departamento': departamento,
    if (direccion != null) 'direccion': direccion,
  };
}
