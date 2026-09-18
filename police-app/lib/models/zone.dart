class Zone {
  final String pincode;
  final String name;
  final String riskLevel;
  final double lat;
  final double lng;

  const Zone({
    required this.pincode,
    required this.name,
    required this.riskLevel,
    required this.lat,
    required this.lng,
  });

  static const List<Zone> chennaiZones = [
    Zone(pincode: '600001', name: 'Parrys',       riskLevel: 'HIGH',   lat: 13.0908, lng: 80.2866),
    Zone(pincode: '600006', name: 'Vepery',        riskLevel: 'HIGH',   lat: 13.0900, lng: 80.2757),
    Zone(pincode: '600007', name: 'Perambur',      riskLevel: 'HIGH',   lat: 13.1186, lng: 80.2487),
    Zone(pincode: '600058', name: 'Royapuram',     riskLevel: 'HIGH',   lat: 13.1127, lng: 80.2966),
    Zone(pincode: '600081', name: 'Manali',        riskLevel: 'HIGH',   lat: 13.1675, lng: 80.2617),
    Zone(pincode: '600002', name: 'Park Town',     riskLevel: 'MEDIUM', lat: 13.0827, lng: 80.2707),
    Zone(pincode: '600003', name: 'Triplicane',    riskLevel: 'MEDIUM', lat: 13.0569, lng: 80.2787),
    Zone(pincode: '600011', name: 'Perambur',      riskLevel: 'MEDIUM', lat: 13.0732, lng: 80.2609),
    Zone(pincode: '600015', name: 'Mylapore',      riskLevel: 'LOW',    lat: 13.0339, lng: 80.2707),
    Zone(pincode: '600017', name: 'Adyar',         riskLevel: 'LOW',    lat: 13.0067, lng: 80.2570),
    Zone(pincode: '600032', name: 'T Nagar',       riskLevel: 'LOW',    lat: 13.0350, lng: 80.2323),
    Zone(pincode: '600040', name: 'Anna Nagar',    riskLevel: 'LOW',    lat: 13.0850, lng: 80.2101),
    Zone(pincode: '600024', name: 'Velachery',     riskLevel: 'LOW',    lat: 12.9815, lng: 80.2209),
    Zone(pincode: '600028', name: 'Besant Nagar',  riskLevel: 'LOW',    lat: 12.9995, lng: 80.2666),
  ];
}
