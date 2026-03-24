import 'dart:convert';
import 'dart:math' as math;

class CampusStop {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final int fareKobo;

  CampusStop({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.fareKobo,
  });

  factory CampusStop.fromJson(Map<String, dynamic> json) {
    return CampusStop(
      id: json['id'],
      name: json['name'],
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      fareKobo: ((json['fare_naira'] as num).toInt()) * 100, // For local MVP parsing
    );
  }
}

class GeofenceManager {
  List<CampusStop> _stops = [];

  // Used for MVP testing without server sync
  static const String MVP_STOPS_JSON = '''[
    { "id": "S1", "name": "Main Gate",      "lat": 7.3775, "lng": 3.9470, "fare_naira": 30  },
    { "id": "S2", "name": "Faculty Block",  "lat": 7.3790, "lng": 3.9490, "fare_naira": 50  },
    { "id": "S3", "name": "Library",        "lat": 7.3810, "lng": 3.9510, "fare_naira": 70  },
    { "id": "S4", "name": "Hostel A",       "lat": 7.3830, "lng": 3.9530, "fare_naira": 85  },
    { "id": "S5", "name": "Sports Complex", "lat": 7.3850, "lng": 3.9550, "fare_naira": 100 }
  ]''';

  Future<void> loadStops() async {
    // In prod, this would load from a local asset or DB updated via sync
    final List<dynamic> data = jsonDecode(MVP_STOPS_JSON);
    _stops = data.map((json) => CampusStop.fromJson(json)).toList();
  }

  /// Finds the nearest campus stop within `radiusMeters` of given coordinates
  CampusStop? getNearestStop(double currentLat, double currentLng, {double radiusMeters = 100.0}) {
    if (_stops.isEmpty) return null;

    CampusStop? nearest;
    double minDistance = double.infinity;

    for (final stop in _stops) {
      final distance = _haversineDistance(currentLat, currentLng, stop.lat, stop.lng);
      if (distance <= radiusMeters && distance < minDistance) {
        minDistance = distance;
        nearest = stop;
      }
    }
    return nearest;
  }

  /// Calculates the great-circle distance between two points in meters
  static double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusMeters = 6371000;
    
    // Convert to radians
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    final radLat1 = _degreesToRadians(lat1);
    final radLat2 = _degreesToRadians(lat2);

    // Apply formula
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLon / 2) * math.sin(dLon / 2) * math.cos(radLat1) * math.cos(radLat2);
    final c = 2 * math.asin(math.sqrt(a));

    return earthRadiusMeters * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }
}
