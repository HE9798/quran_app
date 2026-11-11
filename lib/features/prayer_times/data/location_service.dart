import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../qibla/qibla_math.dart';

class UserLocation {
  const UserLocation({
    required this.lat,
    required this.lng,
    required this.city,
    required this.country,
    required this.countryCode,
  });

  final double lat;
  final double lng;
  final String city; //        "Cairo"
  final String country; //     "Egypt"
  final String countryCode; // "EG" (may be empty if the lookup failed)

  String get label => country.isEmpty ? city : '$city, $country';

  double distanceKmTo(UserLocation other) =>
      distanceKm(lat, lng, other.lat, other.lng);

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'city': city,
        'country': country,
        'cc': countryCode,
      };

  factory UserLocation.fromJson(Map<String, dynamic> json) => UserLocation(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        city: (json['city'] ?? '') as String,
        country: (json['country'] ?? '') as String,
        countryCode: (json['cc'] ?? '') as String,
      );
}

enum LocationProblem { serviceOff, denied, deniedForever, unavailable }

class LocationException implements Exception {
  const LocationException(this.problem);
  final LocationProblem problem;

  @override
  String toString() => 'LocationException($problem)';
}

/// Finds where the phone is, and remembers the last place.
class LocationService {
  LocationService._();
  static final instance = LocationService._();

  static const _key = 'location_v1';

  /// The last place we found, or null on the very first launch.
  Future<UserLocation?> cached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      return UserLocation.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Asks for permission when needed, reads the GPS/network position and
  /// turns it into a city name. Throws [LocationException].
  Future<UserLocation> detect() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(LocationProblem.serviceOff);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException(LocationProblem.denied);
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(LocationProblem.deniedForever);
    }

    Position position;
    try {
      // City-level accuracy is plenty for prayer times and saves battery.
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last == null) {
        throw const LocationException(LocationProblem.unavailable);
      }
      position = last;
    }

    var city = '';
    var country = '';
    var countryCode = '';
    try {
      final places = await Geocoding()
          .placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 8));
      if (places.isNotEmpty) {
        final p = places.first;
        city = _firstNotEmpty([
          p.locality,
          p.subAdministrativeArea,
          p.administrativeArea,
        ]);
        country = p.country ?? '';
        countryCode = (p.isoCountryCode ?? '').toUpperCase();
      }
    } catch (_) {
      // No name is not a problem: the times only need the coordinates.
    }
    if (city.isEmpty) city = 'Your location';

    final location = UserLocation(
      lat: position.latitude,
      lng: position.longitude,
      city: city,
      country: country,
      countryCode: countryCode,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(location.toJson()));
    } catch (_) {}
    return location;
  }

  /// Opens the phone's settings so the user can switch on what is missing.
  Future<void> openSettings(LocationProblem problem) async {
    if (problem == LocationProblem.serviceOff) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  static String _firstNotEmpty(List<String?> values) {
    for (final v in values) {
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }
}
