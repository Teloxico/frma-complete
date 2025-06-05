import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

/// Manages device location retrieval and map launching.
class LocationService {
  Position? _lastPosition;
  String? _lastFormattedAddress;
  DateTime? _lastLocationTime;

  /// Checks if location services are enabled and permissions granted.
  Future<bool> _handleLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      debugPrint('Location services disabled.');
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permission denied.');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permission permanently denied.');
      return false;
    }

    return true;
  }

  /// Returns a human-readable address or error message; caches result for 1 minute.
  Future<String> getCurrentLocation() async {
    if (!await _handleLocationPermission()) {
      return 'Location access denied.';
    }

    if (_lastPosition != null &&
        _lastFormattedAddress != null &&
        _lastLocationTime != null &&
        DateTime.now().difference(_lastLocationTime!).inMinutes < 1) {
      debugPrint('Using cached address.');
      return _lastFormattedAddress!;
    }

    try {
      debugPrint('Fetching new position...');
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      );
      _lastPosition = pos;
      _lastLocationTime = DateTime.now();

      final addr = await _getAddressFromLatLng(pos);
      _lastFormattedAddress = addr;
      return addr;
    } on TimeoutException {
      debugPrint('Position fetch timeout.');
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _lastPosition = last;
        return '${await _getAddressFromLatLng(last)} (stale)';
      }
      return 'Unable to get location (timeout).';
    } catch (e) {
      debugPrint('Error obtaining location: $e');
      return 'Unable to determine location.';
    }
  }

  /// Converts latitude/longitude to an address string; falls back to coordinates.
  Future<String> _getAddressFromLatLng(Position position) async {
    final coords = 'Lat: ${position.latitude.toStringAsFixed(5)}, '
        'Lon: ${position.longitude.toStringAsFixed(5)}';
    if (kIsWeb) return '$coords (Web)';

    try {
      final places = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (places.isNotEmpty) {
        final p = places.first;
        final parts = [p.street, p.locality, p.administrativeArea, p.country]
            .where((s) => s?.isNotEmpty == true)
            .cast<String>()
            .toList();
        if (parts.isNotEmpty) return parts.join(', ');
      }
    } catch (e) {
      debugPrint('Geocoding failed: $e');
    }
    return coords;
  }

  /// Launches the default map app at the last known or newly fetched location.
  Future<bool> openLocationInMap() async {
    Position? target = _lastPosition;
    if (target == null) {
      if (!await _handleLocationPermission()) return false;
      try {
        target = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        );
        _lastPosition = target;
      } catch (_) {
        target ??= await Geolocator.getLastKnownPosition();
      }
    }

    if (target == null) {
      debugPrint('No position available for map launch.');
      return false;
    }

    final lat = target.latitude;
    final lon = target.longitude;
    final coord = '$lat,$lon';
    final appleUrl = Uri.parse('https://maps.apple.com/?q=$coord');
    final googleUrl =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$coord');
    final geoUrl = Uri.parse('geo:$coord?q=$coord');

    try {
      if (!kIsWeb && Platform.isIOS && await canLaunchUrl(appleUrl)) {
        return launchUrl(appleUrl);
      }
      if (await canLaunchUrl(googleUrl)) {
        return launchUrl(googleUrl);
      }
      if (await canLaunchUrl(geoUrl)) {
        return launchUrl(geoUrl);
      }
      debugPrint('No map app available.');
    } catch (e) {
      debugPrint('Error launching map: $e');
    }
    return false;
  }
}
