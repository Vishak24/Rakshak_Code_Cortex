// Stub for geocoding package on web — geocoding is not supported on web.
// The kIsWeb guard in sentinel_controller.dart ensures this is never called.

class Placemark {
  final String? postalCode;
  final String? subLocality;
  final String? locality;
  const Placemark({this.postalCode, this.subLocality, this.locality});
}

Future<List<Placemark>> placemarkFromCoordinates(
  double latitude,
  double longitude, {
  String? localeIdentifier,
}) async {
  return [];
}
