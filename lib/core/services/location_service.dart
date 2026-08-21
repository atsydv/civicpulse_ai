import 'package:geolocator/geolocator.dart';

class LocationService {
  // Default to Prayagraj, India
  static const double defaultLat = 25.4358;
  static const double defaultLng = 81.8463;

  static Future<Map<String, double>> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return {'latitude': defaultLat, 'longitude': defaultLng};
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return {'latitude': defaultLat, 'longitude': defaultLng};
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return {'latitude': defaultLat, 'longitude': defaultLng};
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return {'latitude': position.latitude, 'longitude': position.longitude};
    } catch (e) {
      return {'latitude': defaultLat, 'longitude': defaultLng};
    }
  }

  static String formatCoordinates(double lat, double lng) {
    final latDir = lat >= 0 ? 'N' : 'S';
    final lngDir = lng >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(4)}°$latDir, ${lng.abs().toStringAsFixed(4)}°$lngDir';
  }
}
