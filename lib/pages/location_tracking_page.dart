import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class LocationTrackingPage extends StatefulWidget {
  final String scheduleId;
  final Map<String, dynamic> bookingData;

  const LocationTrackingPage({
    super.key,
    required this.scheduleId,
    required this.bookingData,
  });

  @override
  State<LocationTrackingPage> createState() => _LocationTrackingPageState();
}

class _LocationTrackingPageState extends State<LocationTrackingPage>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  StreamSubscription<DocumentSnapshot>? _locationSubscription;

  LatLng? _driverLocation;
  LatLng? _userLocation;
  Set<Marker> _markers = {};

  bool _isLoading = true;
  bool _isDriverLocationActive = false;
  String _estimatedTime = '';
  double _distance = 0;
  DateTime? _lastLocationUpdate;

  // Animation controller for pulse effect
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _initializePulseAnimation();
    _initializeTracking();
  }

  void _initializePulseAnimation() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initializeTracking() async {
    try {
      // Get user's current location
      final position = await _getCurrentPosition();
      if (position != null) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
        });
      }

      // Start listening to driver location updates
      _startDriverLocationStream();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error initializing tracking: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Position?> _getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      print('Error getting position: $e');
      return null;
    }
  }

  void _startDriverLocationStream() {
    print(
      'Starting real-time location stream for schedule: ${widget.scheduleId}',
    );

    _locationSubscription = FirebaseFirestore.instance
        .collection('driver_locations')
        .doc(widget.scheduleId)
        .snapshots()
        .listen(
          (snapshot) {
            print('Location update received: ${snapshot.exists}');

            if (snapshot.exists) {
              final data = snapshot.data() as Map<String, dynamic>;
              final lat = data['latitude'] as double?;
              final lng = data['longitude'] as double?;
              final timestamp = data['timestamp'] as Timestamp?;

              print('New driver location: $lat, $lng');

              if (lat != null && lng != null) {
                setState(() {
                  _driverLocation = LatLng(lat, lng);
                  _isDriverLocationActive = true;
                  _lastLocationUpdate = timestamp?.toDate() ?? DateTime.now();
                });

                _updateMapAndMarkers();
                _calculateDistanceAndTime();

                // Show location update feedback
                // _showLocationUpdateFeedback();
              }
            } else {
              print('⚠️ Driver stopped sharing location');
              setState(() {
                _isDriverLocationActive = false;
                _driverLocation = null;
              });
              // _showLocationStoppedMessage();
            }
          },
          onError: (error) {
            print('Location stream error: $error');
          },
        );
  }

  // void _showLocationUpdateFeedback() {
  //   ScaffoldMessenger.of(context).hideCurrentSnackBar();
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Row(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           Icon(Icons.location_on, color: Colors.white, size: 16),
  //           SizedBox(width: 8),
  //           Text('Location updated'),
  //         ],
  //       ),
  //       duration: Duration(seconds: 1),
  //       backgroundColor: Colors.green,
  //       behavior: SnackBarBehavior.floating,
  //       margin: EdgeInsets.only(
  //         bottom: MediaQuery.of(context).size.height - 150,
  //         left: 20,
  //         right: 20,
  //       ),
  //     ),
  //   );
  // }

  void _updateMapAndMarkers() {
    if (_driverLocation == null) return;

    Set<Marker> markers = {};

    // Driver marker with custom info
    markers.add(
      Marker(
        markerId: const MarkerId('driver'),
        position: _driverLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(
          title: 'Your Driver',
          snippet: 'Last updated: ${_getLastUpdateText()}',
        ),
      ),
    );

    // User marker (if available)
    if (_userLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user'),
          position: _userLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'You are here',
          ),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });

    // Auto-center map on driver location
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_driverLocation!, 16.0),
      );
    }
  }

  void _calculateDistanceAndTime() {
    if (_driverLocation == null || _userLocation == null) return;

    final distance = Geolocator.distanceBetween(
      _userLocation!.latitude,
      _userLocation!.longitude,
      _driverLocation!.latitude,
      _driverLocation!.longitude,
    );

    setState(() {
      _distance = distance / 1000; // Convert to kilometers
      _estimatedTime = _calculateEstimatedArrival(distance);
    });
  }

  String _calculateEstimatedArrival(double distanceInMeters) {
    const double averageSpeedKmh = 30.0;
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
      return '${hours}h ${remainingMinutes}m';
    }
  }

  String _getLastUpdateText() {
    if (_lastLocationUpdate == null) return 'Just now';

    final now = DateTime.now();
    final difference = now.difference(_lastLocationUpdate!);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          children: [Text('Track Driver', style: TextStyle(fontSize: 20))],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshLocation,
            tooltip: 'Refresh Location',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading driver location...'),
                ],
              ),
            )
          : Column(
              children: [
                // Real-time status banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: _isDriverLocationActive
                      ? Colors.green[50]
                      : Colors.orange[50],
                  child: Row(
                    children: [
                      AnimatedSwitcher(
                        duration: Duration(milliseconds: 300),
                        child: Icon(
                          _isDriverLocationActive
                              ? Icons.location_on
                              : Icons.location_off,
                          color: _isDriverLocationActive
                              ? Colors.green[700]
                              : Colors.orange[700],
                          key: ValueKey(_isDriverLocationActive),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isDriverLocationActive
                                  ? 'Driver location is live'
                                  : 'Driver location unavailable',
                              style: TextStyle(
                                color: _isDriverLocationActive
                                    ? Colors.green[700]
                                    : Colors.orange[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_lastLocationUpdate != null)
                              Text(
                                'Last update: ${_getLastUpdateText()}',
                                style: TextStyle(
                                  color: _isDriverLocationActive
                                      ? Colors.green[600]
                                      : Colors.orange[600],
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Trip Info Card
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _distance > 0
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Column(
                              children: [
                                Icon(
                                  Icons.straighten,
                                  color: Colors.blue[600],
                                  size: 24,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Distance',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_distance.toStringAsFixed(1)} km',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              height: 50,
                              width: 1,
                              color: Colors.grey[300],
                            ),
                            Column(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  color: Colors.green[600],
                                  size: 24,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'ETA',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _estimatedTime,
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.location_searching,
                                color: Colors.grey[400],
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Waiting for location data...',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),

                // Map showing real-time location
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target:
                              _driverLocation ??
                              const LatLng(13.7563, 100.5018),
                          zoom: 14,
                        ),
                        onMapCreated: (GoogleMapController controller) {
                          _mapController = controller;
                        },
                        markers: _markers,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        compassEnabled: true,
                        zoomControlsEnabled: false,
                        mapType: MapType.normal,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 40),
                ],
            ),
    );
  }

  // void _showLocationStoppedMessage() {
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     const SnackBar(
  //       content: Text('⚠️ Driver stopped sharing location'),
  //       backgroundColor: Colors.red,
  //       duration: Duration(seconds: 3),
  //     ),
  //   );
  // }

  void _refreshLocation() {
    setState(() {
      _isLoading = true;
    });

    _initializeTracking().then((_) {
    });
  }
}
