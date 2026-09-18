import 'package:flutter/material.dart' show Color;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';
import '../models/zone.dart';

/// Returns the risk level for a given pincode string, or 'LOW' as default.
String _riskForPincode(String pincode) {
  final zone = Zone.chennaiZones.firstWhere(
    (z) => z.pincode == pincode,
    orElse: () => const Zone(pincode: '', name: '', riskLevel: 'LOW', lat: 0, lng: 0),
  );
  return zone.riskLevel;
}

/// Fill + border colors per risk level, matching the dashboard exactly.
/// Dashboard fills: HIGH=0.20, MEDIUM=0.15, LOW=0.10
/// Dashboard weights: HIGH=1.5, MEDIUM=1.0, LOW=0.8
({Color fill, Color border, double strokeWidth}) _colorsForRisk(String risk) {
  switch (risk.toUpperCase()) {
    case 'HIGH':
      return (
        fill:        const Color(0xFFef4444).withValues(alpha: 0.20),
        border:      const Color(0xFFef4444).withValues(alpha: 0.90),
        strokeWidth: 1.5,
      );
    case 'MEDIUM':
      return (
        fill:        const Color(0xFFf59e0b).withValues(alpha: 0.15),
        border:      const Color(0xFFf59e0b).withValues(alpha: 0.90),
        strokeWidth: 1.0,
      );
    case 'LOW':
      return (
        fill:        const Color(0xFF22c55e).withValues(alpha: 0.10),
        border:      const Color(0xFF22c55e).withValues(alpha: 0.90),
        strokeWidth: 0.8,
      );
    default: // unknown pincode — treat as LOW
      return (
        fill:        const Color(0xFF22c55e).withValues(alpha: 0.10),
        border:      const Color(0xFF22c55e).withValues(alpha: 0.70),
        strokeWidth: 0.8,
      );
  }
}

/// Parses Final_Chennai_Pincode.kml from assets and returns a list of
/// [Polygon] objects coloured by risk level.
///
/// [riskOverrides] — optional map of pincode → risk level to override
/// the defaults from [Zone.chennaiZones].
Future<List<Polygon>> loadKmlZones({Map<String, String>? riskOverrides}) async {
  final kmlString = await rootBundle.loadString('assets/Final_Chennai_Pincode.kml');
  final document  = XmlDocument.parse(kmlString);
  final placemarks = document.findAllElements('Placemark');

  final polygons = <Polygon>[];

  for (final placemark in placemarks) {
    // Extract pincode from SimpleData or <name>
    final simpleData = placemark
        .findAllElements('SimpleData')
        .where((e) => e.getAttribute('name') == 'Pincode')
        .firstOrNull;
    final pincode = simpleData?.innerText.trim() ??
        placemark.findElements('name').firstOrNull?.innerText.trim() ??
        '';

    final coordsEl = placemark.findAllElements('coordinates').firstOrNull;
    if (coordsEl == null) continue;

    final points = coordsEl.innerText
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.contains(','))
        .map((pair) {
          final parts = pair.split(',');
          if (parts.length < 2) return null;
          final lng = double.tryParse(parts[0]);
          final lat = double.tryParse(parts[1]);
          if (lat == null || lng == null) return null;
          return LatLng(lat, lng);
        })
        .whereType<LatLng>()
        .toList();

    if (points.length < 3) continue;

    final risk   = riskOverrides?[pincode] ?? _riskForPincode(pincode);
    final colors = _colorsForRisk(risk);

    polygons.add(Polygon(
      points:            points,
      color:             colors.fill,
      borderColor:       colors.border,
      borderStrokeWidth: colors.strokeWidth,
    ));
  }

  return polygons;
}
