import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // USER-SPECIFIC METHODS
  // =====================

  /// Get real-time driver location stream for tracking
  Stream<DocumentSnapshot> getDriverLocationStream(String scheduleId) {
    print('👀 Starting to watch driver location for schedule: $scheduleId');
    
    return FirebaseFirestore.instance
        .collection('driver_locations')
        .doc(scheduleId)
        .snapshots();
  }

  /// Check if driver is sharing location for this schedule
  Future<bool> isDriverSharingLocation(String scheduleId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('schedules')
          .doc(scheduleId)
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['locationSharingActive'] ?? false;
      }
      return false;
    } catch (e) {
      print('❌ Error checking driver location sharing status: $e');
      return false;
    }
  }

  /// Get driver's last known location
  Future<Map<String, dynamic>?> getDriverLastLocation(String scheduleId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('driver_locations')
          .doc(scheduleId)
          .get();
      
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('❌ Error getting driver last location: $e');
      return null;
    }
  }

  /// Stream to watch if driver starts/stops sharing location
  Stream<DocumentSnapshot> getLocationSharingStatusStream(String scheduleId) {
    return FirebaseFirestore.instance
        .collection('schedules')
        .doc(scheduleId)
        .snapshots();
  }

  // USER LOCATION METHODS 
  // =====================
  // Note: Users do NOT share their location - they only view driver location

  // SHARED UTILITY METHODS
  // ======================

  /// Request location permissions
  Future<bool> requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('❌ Location permissions are denied');
          return false;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        print('❌ Location permissions are permanently denied');
        return false;
      }

      print('✅ Location permissions granted');
      return true;
    } catch (e) {
      print('❌ Error requesting location permission: $e');
      return false;
    }
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Get current user position
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) return null;

      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      print('❌ Error getting current position: $e');
      return null;
    }
  }

  /// Calculate distance between user and driver
  double calculateDistanceToDriver(
    double userLat, 
    double userLng,
    double driverLat, 
    double driverLng
  ) {
    return Geolocator.distanceBetween(
      userLat,
      userLng,
      driverLat,
      driverLng,
    );
  }

  /// Calculate estimated time to reach user (basic calculation)
  String calculateEstimatedArrival(double distanceInMeters, {double averageSpeedKmh = 30.0}) {
    final distanceKm = distanceInMeters / 1000;
    final timeInHours = distanceKm / averageSpeedKmh;
    final timeInMinutes = (timeInHours * 60).round();
    
    if (timeInMinutes < 1) {
      return 'Arriving soon';
    } else if (timeInMinutes == 1) {
      return '1 minute';
    } else if (timeInMinutes < 60) {
      return '$timeInMinutes minutes';
    } else {
      final hours = timeInMinutes ~/ 60;
      final remainingMinutes = timeInMinutes % 60;
      if (remainingMinutes == 0) {
        return '${hours}h';
      } else {
        return '${hours}h ${remainingMinutes}m';
      }
    }
  }

  /// Format timestamp for display
  String formatLastUpdateTime(DateTime lastUpdate) {
    final now = DateTime.now();
    final difference = now.difference(lastUpdate);
    
    if (difference.inSeconds < 30) {
      return 'Just now';
    } else if (difference.inMinutes < 1) {
      return '${difference.inSeconds} seconds ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'More than 1 hour ago';
    }
  }

  /// Check if location data is stale
  bool isLocationDataStale(DateTime lastUpdate, {int maxMinutes = 5}) {
    final now = DateTime.now();
    final difference = now.difference(lastUpdate);
    return difference.inMinutes > maxMinutes;
  }
}