import 'dart:math' as math;

/// The Kaaba in Makkah.
const double kaabaLat = 21.422487;
const double kaabaLng = 39.826206;

double _rad(double deg) => deg * math.pi / 180;
double _deg(double rad) => rad * 180 / math.pi;

/// Direction (0-360, clockwise from true north) you face to look at the Kaaba
/// from [lat], [lng]. Great-circle initial bearing.
double qiblaBearing(double lat, double lng) {
  final phi1 = _rad(lat);
  final phi2 = _rad(kaabaLat);
  final dLng = _rad(kaabaLng - lng);
  final y = math.sin(dLng) * math.cos(phi2);
  final x = math.cos(phi1) * math.sin(phi2) -
      math.sin(phi1) * math.cos(phi2) * math.cos(dLng);
  return (_deg(math.atan2(y, x)) + 360) % 360;
}

/// Straight-line (great-circle) distance in km between two points.
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double distanceToKaabaKm(double lat, double lng) =>
    distanceKm(lat, lng, kaabaLat, kaabaLng);

/// "South-east", "North" ... for a bearing in degrees.
String compassName(double degrees) {
  const names = [
    'North', 'North-east', 'East', 'South-east',
    'South', 'South-west', 'West', 'North-west',
  ];
  return names[(((degrees % 360) + 360) % 360 / 45).round() % 8];
}

/// Smallest signed difference a - b in degrees, in the range -180..180.
double angleDiff(double a, double b) {
  var d = (a - b) % 360;
  if (d > 180) d -= 360;
  if (d < -180) d += 360;
  return d;
}
